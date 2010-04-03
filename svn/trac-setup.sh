#!/bin/sh

function usage {
    echo "$0 <trac_dir> <username>";
    exit 0;
}

TRAC_DIR=$1;
TRAC_USER=$2;
TRAC_ADMIN="trac-admin";

[ -z $TRAC_DIR  ] && usage;
[ -z $TRAC_USER ] && usage;

$TRAC_ADMIN $TRAC_DIR permission remove anonymous               \
            TICKET_CREATE TICKET_MODIFY WIKI_CREATE WIKI_MODIFY \
            ;
$TRAC_ADMIN $TRAC_DIR permission add $TRAC_USER                            \
            TICKET_CREATE TICKET_MODIFY WIKI_CREATE WIKI_MODIFY TRAC_ADMIN \
            ;

exit 0;