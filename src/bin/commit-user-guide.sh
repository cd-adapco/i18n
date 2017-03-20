#!/bin/sh
# set rel or dev
CVS_MODULES="doc/tutorials doc/book/graphics"
SF_BRANCH="doc_en"
SF_WORKSPACE="$WORKSPACE/sf"
CDNA_WORKSPACE="$WORKSPACE/cdna"

usage() {
echo "Usage: $0 -branch [dev|rel]"
echo "$@"
exit 1
}

commit_code() {
# Start committing process
echo "cvs commit to sourceforge"
CVSROOT=:ext:jinteck@i18n.cvs.sourceforge.net:/cvsroot/i18n
export CVSROOT
CVS_RSH=ssh
export CVS_RSH
mkdir -p $SF_WORKSPACE
cd $SF_WORKSPACE
[ -d "$SF_BRANCH" ] && \rm -r "$SF_BRANCH"
echo "cvs checkout $SF_BRANCH"
cvs -Q co "$SF_BRANCH"
cvs -Q update -CPd "$SF_BRANCH"

# if cvs directory but empty, try to cvs checkout
[ -d "$SF_BRANCH" ] || cvs -Q co "$SF_BRANCH"

# if cvs directory does not exist, cvs add
if [ ! -d "$SF_BRANCH" ] ; then 
    mkdir "$SF_BRANCH" 
    echo "rsync -az $CDNA_WORKSPACE/$CVS_MODULE $SF_WORKSPACE/$SF_BRANCH/ --exclude CVS"
    rsync -az $CDNA_WORKSPACE/$CVS_MODULE $SF_WORKSPACE/$SF_BRANCH/ --exclude CVS
    echo "cd $SF_BRANCH && cvs import -m Updated localized files from cdna into sourceforge, $CVS_MODULES -> $SF_BRANCH ($VERSION) $SF_BRANCH CCMP rel-$CVS_VERSION"
    cd "$SF_BRANCH"
    cvs -Q import -m "Updated localized files from cdna into sourceforge, $CVS_MODULES -> $SF_BRANCH ($VERSION)" $SF_BRANCH CCMP rel-$CVS_VERSION
    cd $SF_WORKSPACE
    \rm -rf $SF_BRANCH
    cvs -Q co "$SF_BRANCH"
fi

mkdir -p $SF_WORKSPACE/$SF_BRANCH

for CVS_MODULE in $CVS_MODULES ; do
    echo "rsync -az $CDNA_WORKSPACE/$CVS_MODULE $SF_WORKSPACE/$SF_BRANCH/ --exclude CVS"
    rsync -az $CDNA_WORKSPACE/$CVS_MODULE $SF_WORKSPACE/$SF_BRANCH/ --exclude CVS
done


cd $SF_WORKSPACE/$SF_BRANCH

# cvs add recursively
cvs-add 

# cvs commit recursively
cvs commit -m "Updated localized files from cdna into sourceforge, $CVS_MODULES -> $SF_BRANCH ($VERSION)" .
}

while [ $# -gt 0 ]; do
    case "$1" in
	-branch )
	[ $# -lt 2 ] && usage "Error: missing argument using -branch"
	CVS_BRANCH="$2"
	case "$CVS_BRANCH" in
	    dev | rel )
	    ;;
	    
	    * )
	    usage "Error: -branch is valid only for dev|rel"
	    ;;
	esac
	shift
	;;

        -help | * )
	usage
	;;
    esac
    shift
done

[ -z "$CVS_BRANCH" ]   && usage "Error: -branch is not specified"

# Get version
if [ "$CVS_BRANCH" = "rel" ] ; then
CVSROOT=:pserver:test@relsrv.lebanon.cd-adapco.com:/home/release/cvsroot
STARMIRROR=/home/release/cruise/dev
else
CVSROOT=:pserver:test@starcvs.lebanon.cd-adapco.com:/home/dev/cvsroot
STARMIRROR=/home/star/mirror
fi
export CVSROOT
\rm -rf $CDNA_WORKSPACE
mkdir -p $CDNA_WORKSPACE
cd $CDNA_WORKSPACE

# get version
cvs -q co doc/VERSION
VERSION=`get-bn doc/VERSION -bn`
CVS_VERSION=`get-bn doc/VERSION -cvs`
VERSION_HUDSON="STAR-CCM+ $VERSION"
echo "VERSION_HUDSON=$VERSION_HUDSON"

# checkout latest doc
echo "cvs checkout $CVS_MODULES"
cvs -Q co $CVS_MODULES
echo "cvs update $CVS_MODULES"
cvs -Q update -CPd $CVS_MODULES

commit_code

cd $CDNA_WORKSPACE/doc
cvs tag sf$CVS_VERSION

