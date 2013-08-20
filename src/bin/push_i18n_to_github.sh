#!/bin/sh
usage() {
  echo "Usage: $0 -branch [dev|rel] -locale CODE"
  echo "$@"
  exit 1
}

#
# To checkout star-ccm+ source files (release or development)
#
git_checkout_star() {
  # Clone star
  if [ -d "STAR_HOME" ] ; then
    \rm -rf STAR_HOME
  fi
  cd $WORKSPACE
  git clone $GITROOT
  cd $STAR_HOME
  git pull origin master

  # set up some variables depending on release or development 
  if [ "$BRANCH" = "rel" ] ; then
    GIT_BRANCH=`git branch -r | grep "origin/release" | sort -r | head -1 | sed 's/ //g'`
    STARMIRROR=/home/release/mirror
  else
    GIT_BRANCH=stable
    STARMIRROR=/home/star/mirror
  fi

  # create new branch in ccm+ repository (rel or dev) based on $GIT_BRANCH
  git checkout -b $BRANCH $GIT_BRANCH
  git pull
  GIT_BRANCH=`echo $GIT_BRANCH | sed 's^origin/^^g'`
  make java
  cp ${WORKSPACE}/RELEASE_NOTES ${WORKSPACE}/star
  VERSION=`/home/test/hudson/tool/bin/get-bn $STAR_HOME/RELEASE_NOTES -bn`
}

#
# To commit github sources into star-ccm+ git (release or development)
#
git_commit() {
  # some country codes need a suffix
  if [ "$COUNTRY_CODE" = "ru" ] ; then
    MYLOCALE=ru_RU
  else
    MYLOCALE=$COUNTRY_CODE
  fi

  # move the ccmp+ properties files into the right locations in the i18n repository 
  cd $STAR_HOME 
  ant commit -Di18n.lang=$MYLOCALE -Dsrc.dir=$WORKSPACE/i18n/$COUNTRY_CODE -logfile $WORKSPACE/ant-commit.log

  # git commit recursively
  cd $STAR_HOME 
  git status
  git add .
#  git commit -m  "Updated $COUNTRY_CODE properties from sourceforge, $VERSION"
}


while [ $# -gt 0 ]; do
  case "$1" in
    -branch )
      [ $# -lt 2 ] && usage "Error: missing argument using -branch"
      BRANCH="$2"
      case "$BRANCH" in
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

[ -z "$BRANCH" ]  && usage "Error: -branch is not specified"
[ -z "$LOCALES" ] && usage "Error: -locale is not specified"

IFS=,
if [ -z "$WORKSPACE" ] ; then
  BASEDIR=`dirname "$0"`
  WORKSPACE=`cd $BASEDIR/../../.. && pwd`
fi

#STAR_HOME=$WORKSPACE/star
#GITROOT=git@starcvs:star.git
git_checkout_star

# create .dev
\rm -rf .dev
ln -s "$STARMIRROR" .dev

for COUNTRY_CODE in $LOCALES ; do
  echo "Processing localized country: $COUNTRY_CODE"
  git_commit
done

# merge changes in the temporary branches (dev or rel) into the working branch
cd $STAR_HOME 
git checkout $GIT_BRANCH
git pull
git merge $BRANCH
#git push