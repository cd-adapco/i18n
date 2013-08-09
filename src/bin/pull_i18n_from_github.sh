#!/bin/sh

set -ex

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
  $GIT_HOME/git clone $STAR_GIT
  cd $STAR_HOME
  $GIT_HOME/git pull origin master

  # set up some variables depending on release or development
  if [ "$STREAM" = "rel" ] ; then
    MERGE_HEAD=`$GIT_HOME/git branch -r | grep "origin/release" | sort -r | head -1 | sed 's/ //g'`
    STARMIRROR=/home/release/mirror
  else
    MERGE_HEAD=master
    STARMIRROR=/home/star/mirror
  fi

  # create new branch rel or dev based on $GIT_BRANCH
  $GIT_HOME/git checkout -b $STREAM $MERGE_HEAD
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
  $GIT_HOME/git status
  $GIT_HOME/git add .
  $GIT_HOME/git commit -m  "Updated $COUNTRY_CODE properties from sourceforge, $VERSION" | tee $WORKSPACE/commit.log
  LINE_COUNT=`grep -v _$MY_LOCALE.properties $WORKSPACE/commit.log | grep -v 'original line endings' | wc -l`
  if [ $LINE_COUNT -gt 4 ] ; then
    echo "There were $LINE_COUNT lines in the commit message that were not related to"
    echo "the translation files. There should not be more than 4 so there could be a problem."
    exit 1
  fi
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

# not sure why, but when using sudo the path seems to screwed up and git cannot be found
GIT_HOME=/home/star/mirror/git/latest/linux-x86_64/bin
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
cd $WORKSPACE
\rm -rf .dev
ln -s "$STARMIRROR" .dev

for COUNTRY_CODE in $LOCALES ; do
  echo "Processing localized country: $COUNTRY_CODE"
  git_commit
done

# merge changes in the temporary branches dev or rel into the working branch
cd $STAR_HOME
$GIT_HOME/git checkout $MERGE_HEAD
$GIT_HOME/git pull
$GIT_HOME/git merge $WORKING_BRANCH # into MERGE_HEAD
#$GIT_HOME/git push