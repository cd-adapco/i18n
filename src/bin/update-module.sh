#!/bin/sh


#
# To checkout star-ccm+ source files (release or development)
#
cvs_checkout() {
for MODULE in $MODULES ; do
    # Get version
    UPDATE_WORKSPACE=$WORKSPACE/tmp
    mkdir -p $UPDATE_WORKSPACE
    UPDATE_HOME=$UPDATE_WORKSPACE/$MODULE
    if [ "$CVS_BRANCH" = "rel" ] ; then
        CVSROOT=:pserver:test@relsrv.lebanon.cd-adapco.com:/home/release/cvsroot
        STARMIRROR=/home/release/cruise/dev
    else
        CVSROOT=:pserver:test@starcvs.lebanon.cd-adapco.com:/home/dev/cvsroot
        STARMIRROR=/home/star/mirror
    fi
    echo "export CVSROOT=$CVSROOT"
    export CVSROOT
    [ -d "$UPDATE_HOME" ] && \rm -r "$UPDATE_HOME"
    echo "cd  $UPDATE_WORKSPACE && cvs -Q co $MODULE"
    cd  $UPDATE_WORKSPACE && cvs -Q co $MODULE
done
}

#
# To commit sourceforge sources into star-ccm+ cvs (release or development)
#
cvs_commit() {
mkdir -p $UPDATE_HOME
for MODULE in $MODULES ; do
    echo "rsync -az $WORKSPACE/$MODULE/ $UPDATE_HOME/ --exclude CVS"
	  rsync -az $WORKSPACE/$MODULE/ $UPDATE_HOME/ --exclude CVS

    # cvs add recursively
    cd $UPDATE_HOME && cvs-add

    # cvs commit recursively
    cd $UPDATE_HOME && cvs commit -m "Updated $MODULE from sourceforge" .
done
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

	-module )
	[ $# -lt 2 ] && usage "Error: missing argument using -module"
	MODULES="$2"
	shift
	;;

        -help | * )
	usage
	;;
    esac
    shift
done

[ -z "$CVS_BRANCHES" ] && usage "Error: -branch is not specified"
[ -z "$MODULES" ]      && usage "Error: -module is not specified"

IFS=,
for CVS_BRANCH in $CVS_BRANCHES ; do
    echo "Processing CVS branch: $CVS_BRANCH"
    cvs_checkout
    cvs_commit
done
