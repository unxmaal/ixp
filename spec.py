import getopt
import glob
import grp
import os
import pwd
import shutil
import subprocess
import sys
import tempfile

from stat import *
from pathlib import Path

def err(string):
    print(string, file=sys.stderr)

def debug(string):
    if verbose:
        err(string)
        
def usage():
    err("Usage: %s (options) <paths>" % sys.argv[0])
    err(" -d<dir>     create destination paths relative to dir")
    err(" -u<uid>     force uid on all files")
    err(" -g<gid>     force gid on all files")
    err(" -h<header>  use this file as package header")
    err(" -p<name>    package name")
    err(" -t          run epm to create a tardist")
    err(" -v          verbose output")
    err(" -e          output the generated tardist name to stdout after completion")
    sys.exit(2)

if len(sys.argv) < 2:
    usage()
    
force_uid = None
force_gid = None
strip_prefix = None
header_file = None
package_name = None
run_epm = False
workdir = None
output_fd = None
output_fname = None
verbose = False
symlinks = []
echo_tardist = False

try:
    opts, args = getopt.getopt(sys.argv[1:], "u:g:d:h:p:tve")
except getopt.GetoptError as getopt_err:
    # print help information and exit:
    err(getopt_err)  # will print something like "option -a not recognized"
    usage()

for o, a in opts:
    if o == '-g':
        force_gid = int(a)
    elif o == '-u':
        force_uid = int(a)
    elif o == '-d':
        strip_prefix = a
    elif o == '-h':
        header_file = a
    elif o == '-p':
        package_name = a
    elif o == '-t':
        run_epm = True
    elif o == '-v':
        verbose = True
    elif o == '-e':
        echo_tardist = True

paths = args

def get_info(path, known_type=''):
    src = path
    if strip_prefix:
        dst = os.path.relpath(path, strip_prefix)
    else:
        dst = path
    s = os.stat(root)
    mode = S_IMODE(s.st_mode)
    if force_uid is not None:
        owner = pwd.getpwuid(force_uid).pw_name
    else:
        owner = pwd.getpwuid(s.st_uid).pw_name
    if force_gid is not None:
        group = grp.getgrgid(force_gid).gr_name
    else:
        group = grp.getgrgid(s.st_gid).gr_name

    if known_type:
        type = known_type
    elif S_ISLNK(s.st_mode):
        type = 'l'
    else:
        type = 'f'
    return(type, oct(mode)[2:], owner, group, dst, src)

def output(line):
    if run_epm:
        print(line, file=output_fd)
    else:
        print(line)

if run_epm:
    if package_name is None:
        err("With -t you need to specify a package name with -p")
        usage()
    workdir = tempfile.mkdtemp(suffix='-specpy')
    debug("workdir %s" % workdir)
    output_fname = workdir + '/' + package_name + '.list'
    debug("output file %s" % output_fname)
    try:
        output_fd = open(output_fname, 'w+')
    except Exception as e:
        err("can not create %s: %s" % (output_fname, e))
        sys.exit(2)

if header_file is not None:
    with open(header_file) as f:
        # TODO: grab LICENSE and README and symlink to workdir to avoid absolute paths?
        output(f.read())
        
while len(paths):
    path = os.path.abspath(paths.pop())
    debug("processing %s" % path)
    for root, dirs, files in os.walk(path):
        firstpart = Path(root).parts[1]
        debug("entering %s" % root)
        if firstpart not in symlinks:
            symlinks.append(firstpart)
        output("%s %s %s %s \"%s\" \"%s\"" % get_info(root, known_type='d'))
        for file in files:
            fpath = root + '/' + file
            output("%s %s %s %s \"%s\" \"%s\"" % get_info(fpath))

output_fd.close()
            
if run_epm:
    for path in symlinks:
        src = '/' + path
        dst = workdir + '/' + path
        debug("symlinking %s to %s" % (src, dst))
        os.symlink(src, dst)
    args = [
        'epm',
        '-f', 'tardist',
        package_name
    ]
    if verbose:
        args.append('-v')
    debug("running %s" % ' '.join(args))
    cp = subprocess.Popen(args, cwd=workdir)
    cp.wait()
    debug("epm done")
    if cp.returncode:
        err("non-zero epm exit status: %s" % ' '.join(args))
        sys.exit(2)
    tardist = glob.glob(workdir + '/irix-6.5-mips/*.tardist')
    if len(tardist) == 0:
        err("epm set no error code but tardist is missing?")
    if len(tardist) > 1:
        err("more than one tardist found?")
    shutil.copy(tardist[0], '.')
    if echo_tardist:
        # sorry :D
        print(os.path.abspath(os.path.basename(tardist[0])))
    debug("clean up %s" % workdir)
    shutil.rmtree(workdir)
