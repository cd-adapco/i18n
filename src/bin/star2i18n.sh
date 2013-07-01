#!/bin/sh
# set rel or dev
usage() {
echo "Usage: $0 -branch [dev|rel] -locale CODE"
echo "$@"
exit 1
}

setup_star() {
echo "git clone git@starcvs:star.git"
      git clone git@starcvs:star.git

cd $STAR_HOME
if [ $BRANCH = "rel" ] ; then
    GIT_BRANCH=`git branch -r | grep "origin/release" | sort -r | head -1 | sed 's/ //g'`
    git checkout -b rel $GIT_BRANCH
    git pull
    STARMIRROR=/home/release/mirror
else 
    git pull
    STARMIRROR=/home/star/mirror
fi

# create .dev
cd $STAR_HOME/..
\rm -f .dev
ln -s "$STARMIRROR" .dev

# make java
\rm -rf $STAR_HOME/lib/java

echo "gmake version"
cd $STAR_HOME && make version
VERSION=`get-bn $STAR_HOME/RELEASE_NOTES -bn`
echo "gmake java"
cd $STAR_HOME && gmake java -j 4
}

commit_country_code() {
# gather the i18n properties
\rm -rf $STAR_HOME/lib/i18n
echo "Running ant script : ant i18n-$COUNTRY_CODE"
cd $STAR_HOME && ant i18n -Di18n.lang=$COUNTRY_CODE

find $I18N_HOME/$COUNTRY_CODE -iname "*.properties" -not -iname "*$COUNTRY_CODE*properties" -exec \rm -rf {} \;

rsync -avz $STAR_HOME/lib/i18n/ $I18N_HOME/$COUNTRY_CODE/ \
--include="*/" --include="Bundle.properties" --include="Bundle_star.properties" --include="Star.properties" \
--exclude="*"

cd $I18N_HOME
if [ "$COUNTRY_CODE" = "ru" ] ; then
    MYLOCALE=ru_RU
else
    MYLOCALE=$COUNTRY_CODE
fi

# detect English files that were deleted and then delete the corresponding localized files
git status | grep deleted | sed 's/#//g' | sed 's/deleted://g' | sed "s/.properties/_$MYLOCALE.properties/g" | xargs rm -f

git checkout -b $VERSION
git add .
git commit -m "Updated localized files from $BRANCH branch ($VERSION)" .
git checkout master
git pull
git merge $VERSION
git push
}

while [ $# -gt 0 ]; do
    case "$1" in
	-branch )
	[ $# -lt 2 ] && usage "Error: missing argument using -branch"
	BRANCH="$2"
	case "$BRANCH" in
	    dev | rel )
	    ;;
	    
	    * )
	    usage "Error: -branch is valid only for dev|rel"
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

[ -z "$BRANCH" ]   && usage "Error: -branch is not specified"
[ -z "$LOCALES" ] && usage "Error: -locale is not specified"

# Get version
STAR_HOME=`pwd`/star
I18N_HOME=`pwd`/i18n

setup_star

IFS=,
for COUNTRY_CODE in $LOCALES ; do
    commit_country_code
done
