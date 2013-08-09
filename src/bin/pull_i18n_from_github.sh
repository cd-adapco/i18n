#!/bin/sh

set -e

usage() {
  echo "Usage: $0 -branch [dev|rel] -locale CODE"
  echo "$@"
  exit 1
}

#
# To checkout star-ccm+ source files release or development
#
git_checkout_star() {
  # Clone star
  if [ -d "$STAR_HOME" ] ; then
    \rm -rf $STAR_HOME
  fi
  cd $WORKSPACE
  git clone $STAR_GIT
  cd $STAR_HOME
 git pull origin master

  # set up some variables depending on release or development
  if [ "$STREAM" = "rel" ] ; then
    MERGE_HEAD=`git branch -r | grep "origin/release" | sort -r | head -1 | sed 's/ //g'`
    STARMIRROR=/home/release/mirror
  else
    MERGE_HEAD=master
    STARMIRROR=/home/star/mirror
  fi

  # create new branch rel or dev based on $GIT_BRANCH
  git checkout -b $STREAM $MERGE_HEAD
  MERGE_HEAD=`echo $MERGE_HEAD | sed 's^origin/^^g'`
  cp ${WORKSPACE}/RELEASE_NOTES ${WORKSPACE}/star
  VERSION=`/home/test/hudson/tool/bin/get-bn $STAR_HOME/RELEASE_NOTES -bn`
}

#
# To commit github sources into star-ccm+ git release or development
#
git_commit() {
  cd  $SWORKSPACE

  # Organize the properties from sourceforge into starcvs
  if [ "$COUNTRY_CODE" = "ru" ] ; then
    MYLOCALE=ru_RU
  else
    MYLOCALE=$COUNTRY_CODE
  fi

  # Start the committing process
  cd $STAR_HOME
  /home/test/hudson/lib/ant/1.7.1/bin/ant commit -v -Di18n.lang=$MYLOCALE -Dsrc.dir=$WORKSPACE/i18n/$COUNTRY_CODE
  git status
  git add .
  git commit -m  "Updated $COUNTRY_CODE properties from sourceforge, $VERSION"
}

while [ $# -gt 0 ]; do
  case "$1" in
	  -branch )
      if [ $# -lt 2 ] ; then
        usage "Error: missing argument using -branch"
      fi
      STREAM="$2"
      case "$STREAM" in
        dev | rel | "dev,rel" | "rel,dev" )
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

[ -z "$STREAM" ]  && usage "Error: -branch is not specified"
[ -z "$LOCALES" ] && usage "Error: -locale is not specified"

WORKING_BRANCH=$STREAM
IFS=,
if [ -z "$WORKSPACE" ] ; then
  BASEDIR=`dirname "$0"`
  WORKSPACE=`cd $BASEDIR/../../.. && pwd`
fi

STAR_HOME=$WORKSPACE/star
STAR_GIT=git@starcvs:star.git
git_checkout_star

# create .dev
\rm -rf .dev
ln -s "$STARMIRROR" .dev

for COUNTRY_CODE in $LOCALES ; do
  echo "Processing localized country: $COUNTRY_CODE"
  git_commit
done

# merge changes in the temporary branches dev or rel into the working branch
cd $STAR_HOME
git checkout $MERGE_HEAD
git pull
git merge $WORKING_BRANCH # into MERGE_HEAD
#git push