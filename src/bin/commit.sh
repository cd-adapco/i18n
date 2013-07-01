#!/bin/sh
# set rel or dev
usage() {
echo "Usage: $0 -branch [dev|rel] -sfbranch [dev|rel] -locale CODE"
echo "$@"
exit 1
}

commit_country_code() {
# gather the i18n properties
\rm -rf $STAR_HOME/lib/i18n
echo "Running ant script : ant i18n-$COUNTRY_CODE"
cd $STAR_HOME && ant i18n -Di18n.lang=$COUNTRY_CODE

# Start committing process
echo "cvs commit to sourceforge"
CVSROOT=:ext:jinteck@i18n.cvs.sourceforge.net:/cvsroot/i18n
export CVSROOT
CVS_RSH=ssh
export CVS_RSH
cd $WORKSPACE
[ -d "$SF_BRANCH/$COUNTRY_CODE" ] && \rm -r "$SF_BRANCH/$COUNTRY_CODE"
cvs -q co "$SF_BRANCH/$COUNTRY_CODE"
cvs -q update -CPd "$SF_BRANCH/$COUNTRY_CODE"

# if cvs directory but empty, try to cvs checkout
[ -d "$SF_BRANCH/$COUNTRY_CODE" ] || cvs -q co "$SF_BRANCH/$COUNTRY_CODE"

# if cvs directory does not exist, cvs add
if [ ! -d "$SF_BRANCH/$COUNTRY_CODE" ] ; then 
    mkdir "$SF_BRANCH/$COUNTRY_CODE" 
    cvs add "$SF_BRANCH/$COUNTRY_CODE"
fi

mkdir -p $WORKSPACE/$SF_BRANCH/$COUNTRY_CODE
rsync -avz $WORKSPACE/star/lib/i18n/ $WORKSPACE/$SF_BRANCH/$COUNTRY_CODE/ \
--include="*/" --include="Bundle.properties" --include="Bundle_star.properties" --include="Star.properties" \
--exclude="*"
#--exclude "Bundle_$COUNTRY_CODE.properties" \
#--exclude "Bundle_star_$COUNTRY_CODE.properties" \
#--exclude "Star_$COUNTRY_CODE.properties"

cd $WORKSPACE/$SF_BRANCH/$COUNTRY_CODE

# cvs add recursively
cvs-add "Bundle.properties"
cvs-add "Bundle_star.properties"
cvs-add "Star.properties"

# cvs commit recursively
cvs commit -m "Updated localized files from $CVS_BRANCH branch into sourceforge ($VERSION)" .
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

[ -z "$CVS_BRANCH" ]   && usage "Error: -branch is not specified"
[ -z "$SF_BRANCH" ]    && SF_BRANCH="dev"
[ -z "$LOCALES" ] && usage "Error: -locale is not specified"

# Get version
STAR_HOME=$WORKSPACE/star
GITROOT=git@starcvs:star.git
if [ "$CVS_BRANCH" = "rel" ] ; then
STARMIRROR=/home/test/cruise/cfg/release/release
GIT_OPT="--branch release/6.04"
else
STARMIRROR=/home/star/mirror
fi
[ -d star ] && \rm -rf star
echo "git checkout star"
git clone $GITROOT $GIT_OPT
VERSION=`get-bn $STAR_HOME/RELEASE_NOTES -bn`

# create .dev
\rm -f .dev
ln -s "$STARMIRROR" .dev

# make java
\rm -rf $STAR_HOME/lib/java
echo "gmake java"
cd $STAR_HOME && gmake java -j 4

IFS=,
for COUNTRY_CODE in $LOCALES ; do
    commit_country_code
done
