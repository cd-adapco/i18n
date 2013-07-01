#!/bin/sh


#
# To checkout star-ccm+ source files (release or development)
#
cvs_checkout() {
# Get version
STAR_WORKSPACE=$WORKSPACE/tmp
mkdir -p $STAR_WORKSPACE
STAR_HOME=$STAR_WORKSPACE/star
if [ "$CVS_BRANCH" = "rel" ] ; then
CVSROOT=:pserver:test@relsrv.cdnorthamerica.com:/home/release/cvsroot
STARMIRROR=/home/release/cruise/dev
else
CVSROOT=:pserver:test@starcvs.cdnorthamerica.com:/home/dev/cvsroot
STARMIRROR=/home/star/mirror
fi
echo "export CVSROOT=$CVSROOT"
export CVSROOT
[ -d "$STAR_HOME" ] && \rm -r "$STAR_HOME"
echo "cd  $STAR_WORKSPACE && cvs -Q co star"
cd  $STAR_WORKSPACE && cvs -Q co star
echo "$STAR_WORKSPACE && cvs -Q update -CPd star"
cd  $STAR_WORKSPACE && cvs -Q update -CPd star
VERSION=`get-bn $STAR_HOME/RELEASE_NOTES -bn`
VERSION_HUDSON=star-ccm+$VERSION
}

#
# To commit sourceforge sources into star-ccm+ cvs (release or development)
#
cvs_commit() {
# create .dev
[ -L .dev ] || ln -s "$STARMIRROR" .dev

# Start the committing process
[ -d "$STAR_HOME/lib/i18n" ] && \rm -r $STAR_HOME/lib/i18n
mkdir -p $STAR_HOME/lib/i18n
echo "rsync -az $WORKSPACE/$SF_BRANCH/$COUNTRY_CODE/ $STAR_HOME/lib/i18n/ --exclude CVS"
rsync -az $WORKSPACE/$SF_BRANCH/$COUNTRY_CODE/ $STAR_HOME/lib/i18n/ --exclude CVS

# Organize the properties from sourceforge into starcvs
echo "cd $STAR_HOME && ant commit -Di18n.lang=$COUNTRY_CODE -Dsrc.dir=$STAR_HOME/lib/i18n"
cd $STAR_HOME && ant commit -Di18n.lang=$COUNTRY_CODE -Dsrc.dir=$STAR_HOME/lib/i18n

# Remove star/lib to avoid cvs add and commit
\rm -rf $STAR_HOME/lib

# cvs add recursively
cd $STAR_HOME && cvs-add "*$COUNTRY_CODE*.properties"

# cvs commit recursively
cd $STAR_HOME && cvs commit -m "Updated $COUNTRY_CODE properties from sourceforge, $VERSION ($BUILD_ID)" .
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
    echo "Processing CVS branch: $CVS_BRANCH"
    cvs_checkout
    for COUNTRY_CODE in $LOCALES ; do
	echo "Processing localized country: $COUNTRY_CODE"
	cvs_commit
    done
done
