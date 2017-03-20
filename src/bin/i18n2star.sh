#!/bin/sh
usage() {
  echo "Usage: $0 -branch [dev|rel] -locale CODE"
  echo "$@"
  exit 1
}

#
# To checkout star-ccm+ source files (release or development)
#
git_checkout() {
  # Get version
  STAR_WORKSPACE=$WORKSPACE/tmp
  mkdir -p $STAR_WORKSPACE
  STAR_HOME=$STAR_WORKSPACE/star
  GITROOT=git@stash:ups/star.git
  if [ -d "$STAR_HOME" ] ; then
    \rm -rf "$STAR_HOME"
  fi
  cd $STAR_WORKSPACE
  git clone $GITROOT
  cd $STAR_HOME
  git pull origin master

  cd $STAR_HOME
  if [ "$BRANCH" = "rel" ] ; then
    GIT_BRANCH=`git branch -r | grep "origin/release" | sort -r | head -1 | sed 's/ //g'`
    git checkout -b rel $GIT_BRANCH
    git pull
    STARMIRROR=/home/release/mirror
    GIT_BRANCH=`echo $GIT_BRANCH | sed 's^origin/^^g'`
  else
    GIT_BRANCH=master
    STARMIRROR=/home/star/mirror
    git checkout -b dev master
  fi
  make version
  VERSION=`get-bn $STAR_HOME/RELEASE_NOTES -bn`
  VERSION_HUDSON=star-ccm+$VERSION
}

#
# To commit sourceforge sources into star-ccm+ cvs (release or development)
#
git_commit() {
  cd  $STAR_WORKSPACE

  # create .dev
  \rm -rf .dev
  ln -s "$STARMIRROR" .dev

  # Organize the properties from sourceforge into starcvs
  if [ "$COUNTRY_CODE" = "ru" ] ; then
      MYLOCALE=ru_RU
  else
      MYLOCALE=$COUNTRY_CODE
  fi

  # Start the committing process
  if [ -d "$STAR_HOME/lib/i18n" ] ; then
    \rm -r $STAR_HOME/lib/i18n
  fi
  mkdir -p $STAR_HOME/lib/i18n
  rsync -az $WORKSPACE/i18n/$COUNTRY_CODE/ $STAR_HOME/lib/i18n/ --include="*/" --include="*$MYLOCALE.properties" --exclude="*"

  cd $STAR_HOME
  ant commit -Di18n.lang=$MYLOCALE -Dsrc.dir=$STAR_HOME/lib/i18n -logfile $WORKSPACE/ant-commit.log
  read 

  # Remove star/lib to avoid cvs add and commit
  \rm -rf $STAR_HOME/lib

  # git commit recursively
  cd $STAR_HOME
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
      if [ $# -lt 2 ] ; then
        usage "Error: missing argument using -sfbranch"
      fi
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

if [ -z "$BRANCH" ] ; then
  usage "Error: -branch is not specified"
fi
if [ -z "$LOCALES" ] ; then
  usage "Error: -locale is not specified"
fi

IFS=,
if [ -z "$WORKSPACE" ] ; then
  BASEDIR=`dirname "$0"`
  WORKSPACE=`cd $BASEDIR/../../.. && pwd`
fi
git_checkout
for COUNTRY_CODE in $LOCALES ; do
  echo "Processing localized country: $COUNTRY_CODE"
  git_commit
done

cd $STAR_HOME
git checkout $GIT_BRANCH
git pull
git merge $BRANCH
git push
