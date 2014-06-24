#!/bin/sh

#
# To checkout star-ccm+ source files (release or development)
#
cvs_checkout() {
# Get version
STAR_WORKSPACE=$WORKSPACE/tmp
mkdir -p $STAR_WORKSPACE
STAR_HOME=$STAR_WORKSPACE/star
GITROOT=git@stash:ups/star.git
[ -d "$STAR_HOME" ] && \rm -rf "$STAR_HOME"
echo "cd $STAR_WORKSPACE && git clone $GITROOT"
      cd $STAR_WORKSPACE && git clone $GITROOT
echo "cd $STAR_HOME      && git pull origin master"
      cd $STAR_HOME      && git pull origin master
if [ "$CVS_BRANCH" = "rel" ] ; then
    cd $STAR_HOME
    REL_BRANCH=`git branch -r | grep "release/" | sort | tail -1`
    REL_BRANCH=`basename $REL_BRANCH`
    git checkout release/$REL_BRANCH
else
    cd $STAR_HOME && make version
fi

VERSION=`get-bn $STAR_HOME/RELEASE_NOTES -bn`
VERSION_HUDSON=star-ccm+$VERSION
}

#
# To commit sourceforge sources into star-ccm+ cvs (release or development)
#
cvs_commit() {
cd  $STAR_WORKSPACE

# create .dev
STARMIRROR=/home/star/mirror
[ -L .dev ] || ln -s "$STARMIRROR" .dev

# Start the committing process
[ -d "$STAR_HOME/lib/i18n" ] && \rm -r $STAR_HOME/lib/i18n
mkdir -p $STAR_HOME/lib/i18n
echo "rsync -az $WORKSPACE/$SF_BRANCH/$COUNTRY_CODE/ $STAR_HOME/lib/i18n/ --exclude CVS --exclude .git"
      rsync -az $WORKSPACE/$SF_BRANCH/$COUNTRY_CODE/ $STAR_HOME/lib/i18n/ --exclude CVS --exclude .git

# Organize the properties from sourceforge into starcvs
echo "cd $STAR_HOME && ant commit -Di18n.lang=$COUNTRY_CODE -Dsrc.dir=$STAR_HOME/lib/i18n -logfile $WORKSPACE/ant-commit.log"
      cd $STAR_HOME && ant commit -Di18n.lang=$COUNTRY_CODE -Dsrc.dir=$STAR_HOME/lib/i18n -logfile $WORKSPACE/ant-commit.log

# Remove star/lib to avoid cvs add and commit
\rm -rf $STAR_HOME/lib

# git commit recursively
echo "cd $STAR_HOME && git status"
      cd $STAR_HOME && git status
echo "cd $STAR_HOME && git add ."
      cd $STAR_HOME && git add .
echo "cd $STAR_HOME && git commit -m \"Updated $COUNTRY_CODE properties from sourceforge, $VERSION ($BUILD_ID)\""
      cd $STAR_HOME && git commit -m  "Updated $COUNTRY_CODE properties from sourceforge, $VERSION ($BUILD_ID)"
}


while [ $# -gt 0 ]; do
    case "$1" in
	-branch )
	[ $# -lt 2 ] && usage "Error: missing argument using -branch"
	CVS_BRANCHES="$2"
	case "$CVS_BRANCHES" in
	    dev | rel | "dev,rel" | "rel,dev" )
	    ;;
	    
	    * )
	    usage "Error: -branch is valid only for dev|rel"
	    ;;
	esac
	shift
	;;

	-sfbranch )
	[ $# -lt 2 ] && usage "Error: missing argument using -sfbranch"
	SF_BRANCH="$2"
	case "$SF_BRANCH" in
	    dev | rel )
	    ;;
	    
	    * )
	    usage "Error: -sfbranch is valid only for dev|rel"
	    ;;
	esac
	shift
	;;

	-locale )
	[ $# -lt 2 ] && usage "Error: missing argument using -locale"
	LOCALES="$2"
	shift
	;;

        -help | * )
	usage
	;;
    esac
    shift
done

[ -z "$CVS_BRANCHES" ] && usage "Error: -branch is not specified"
[ -z "$SF_BRANCH" ]    && SF_BRANCH="dev"
[ -z "$LOCALES" ]      && usage "Error: -locale is not specified"

IFS=,
for CVS_BRANCH in $CVS_BRANCHES ; do
    echo "Processing git branch: $CVS_BRANCH"
    cvs_checkout
    for COUNTRY_CODE in $LOCALES ; do
	echo "Processing localized country: $COUNTRY_CODE"
	cvs_commit
    done
done
echo "cd $STAR_HOME && git pull"
      cd $STAR_HOME && git pull
echo "cd $STAR_HOME && git push"
      cd $STAR_HOME && git push
