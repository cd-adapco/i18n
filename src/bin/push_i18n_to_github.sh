#!/bin/sh
set -ex

usage() {
  cat << END_HELP
  Usage: $0 -branch [dev|rel] -locale CODE
  $@
  
  Arguments 
      CODE   one or more of ja, ru or zh, 
             in a comma separated list if more than one is given 
  Requirements
      - The github i18n repository must be cloned
      - The WORKSPACE environment variable is set to the 
        directory where the i18n repository was cloned into
END_HELP
  exit 1
}

#
# To checkout star-ccm+ source files (release/X.XX for release or stable for development) 
# and make java to get the english property files
#
checkout_star() {
  # there should not be a star directory in the workspace, but just in case
  if [ -d "$STAR_HOME" ] ; then
    \rm -rf $STAR_HOME
  fi

  # Clone star
  cd $WORKSPACE
  git clone git@stash:ups/star.git
  cd $STAR_HOME
  git pull 

  # set up some variables depending on release or development. If the VERSION
  # variable has not been set then use stable in dev and latest release branch in release
  if [ "$STREAM" = "rel" ] ; then
    if [ -z $VERSION ] ; then
      STAR_TAG=`git branch -r | grep "origin/release/[0-9][0-9]\.[0-9][0-9]" | sort -r | head -1 | sed 's/ //g'`
    else
      RELEASE=`echo $VERSION | sed 's/\(.*\..*\)\..*/\1/'`
      STAR_TAG=origin/release/$RELEASE
    fi
    STARMIRROR=/home/release/mirror
  else
    if [ -z $VERSION ] ; then
      STAR_TAG=stable
    else
      STAR_TAG=$VERSION
    fi
    STARMIRROR=/home/star/mirror
  fi

  # get the correct tag
  git checkout $STAR_TAG
  STAR_TAG=`echo $STAR_TAG | sed 's^origin/^^g'`

  # create .dev and build java which will include the English property
  # files in a jar file
  cd $STAR_HOME/..
  \rm -f .dev
  ln -s "$STARMIRROR" .dev
  cd $STAR_HOME
  gmake java -j 4
  
  # should have started with a clean workspace, but just in case
  # although this directory will be there from a previous language
  \rm -rf $STAR_HOME/lib/i18n

  # unpack the NetBeans jar files and copy all english i18n properties files
  # into star/lib/i18n. This also copies the files for a language even tho 
  # this operation does not need them - did not want to edit the ant script
  # and the language specific files are ignored in the copy to the i18n repository 
  # TODO: check if this should be for loop or if ant script takes comma-separated lang list
  ../ant/bin/ant i18n -Di18n.lang=zh

  # if we don't already have a release notes file from copying artifacts
  # from an upstream job, then generate it
  if [ ! -f ${WORKSPACE}/RELEASE_NOTES ] ; then
    make version
  else
    cp ${WORKSPACE}/RELEASE_NOTES ${WORKSPACE}/star
  fi
  if [ -z "$VERSION" ] ; then
    # TODO: Use a get-bn utility NOT in hudson/tool/bin
    # Don't have top.git here yet
    VERSION=`/home/test/hudson/tool/bin/get-bn $STAR_HOME/RELEASE_NOTES -bn`
  fi
}

#
# commit updated, new and deleted english property files from ccm+ to the i18n
# repository for a particular language
#
copy_to_country() {
  # remove the english properties files from the i18n working directory 
  if [ -d $I18N_HOME/$COUNTRY_CODE ] ; then
    find $I18N_HOME/$COUNTRY_CODE -iname "*.properties" -not -iname "*$COUNTRY_CODE*properties" -exec \rm -rfv {} \;
  fi

  # copy the english files only from star/lib/i18n to the language specific directory in the i18n workspace 
  rsync -avz $STAR_HOME/lib/i18n/ $I18N_HOME/$COUNTRY_CODE/ \
    --include="*/" --include="Bundle.properties" --include="Bundle_star.properties" --include="Star.properties" \
    --exclude="*"

  if [ "$COUNTRY_CODE" = "ru" ] ; then
    MYLOCALE=ru_RU
  else
    MYLOCALE=$COUNTRY_CODE
  fi

  # in the i18n directory, detect English files that were deleted and then delete the corresponding localized files
  cd $I18N_HOME
  git status | grep deleted | sed 's/#//g' | sed 's/deleted://g' | sed "s/.properties/_$MYLOCALE.properties/g" | xargs rm -fv

  git add .
  git diff --quiet --exit-code --cached || git commit -m "Update English properties files in the $COUNTRY_CODE directory from the $STREAM branch, version $VERSION" .
}

# initialize some default values
STREAM_GITHUB=dev

# parse the command line arguments 
while [ $# -gt 0 ]; do
  case "$1" in
    -branch | -branch_github )
      if [ $# -lt 2 ] ; then 
        usage "Error: missing argument using -branch"
      fi
      if [ "$1" = "-branch" ] ; then
        STREAM="$2"
      else
        STREAM_GITHUB="$2"
      fi
      case "$2" in
        dev | rel )
        ;;
	    
        * )
          usage "Error: -branch and -branch_github is valid only for dev|rel"
        ;;
      esac
      shift
    ;;

    -locale )
      if [ $# -lt 2 ] ; then
        usage "Error: missing argument using -locale"
      fi
      LOCALES="$2"
      shift
    ;;

    -help | * )
      usage
    ;;
  esac
  shift
done

if [ -z "$STREAM" ] ; then
  usage "Error: -branch is not specified"
fi
if [ -z "$LOCALES" ] ; then
  usage "Error: -locale is not specified"
fi
if [ -z "$WORKSPACE" ] ; then
  usage "Error: the WORKSPACE environment variable is not specified"
fi
if [ -z "$VERSION"  -a  -f $WORKSPACE/version.properties ] ; then
  . $WORKSPACE/version.properties
fi
STAR_HOME=${WORKSPACE}/star
I18N_HOME=${WORKSPACE}/i18n


# check out the right i18n tag
cd ${I18N_HOME}
if [ "$STREAM_GITHUB" = "dev" ] ; then
  git checkout master
else
  RELEASE=`echo $VERSION | sed 's/\(.*\..*\)\..*/\1/'`
  git checkout release/$RELEASE
fi

# get the english strings
checkout_star

# copy them to i18n and commit them
IFS=,
for COUNTRY_CODE in $LOCALES ; do
  copy_to_country
done

# final push of all updated languages
git push
