#! /usr/bin/env bash


source ~/bin/log.sh
source ~/bin/utils.sh


HOST_NAME_s=`hostname -s`


function  start_socks_7070() { autossh -M 20010 -f seulogin.2alice.site       -D7070 -gfCN -T -e none; }
function verify_socks_7070() { test_port localhost 7070; }
function  start_socks_7071() { autossh -M 20012 -f fuzwvps1.2alice.site       -D7071 -gfCN -T -e none -o 'ProxyCommand nc -x localhost:7070 %h %p'; }
function verify_socks_7071() { test_port localhost 7071; }
function  start_socks_7072() { autossh -M 20014 -f vpn2c-bladesk1.2alice.site -D7072 -gfCN -T -e none; }
function verify_socks_7072() { test_port localhost 7072; }
function  start_socks_7077() { autossh -M 20020 -f localhost                  -D7077 -gfCN -T -e none; }
function verify_socks_7077() { test_port localhost 7077; }
function  start_fwd01_7077() { autossh -M 20022 -f mr-n1-dmz                  -R7077:localhost:7077 -gfCN -T -e none; }
function verify_fwd01_7077() { test_port localhost 20022; }
function  start_fwd02_7077() { autossh -M 20024 -f bj-209-20-22-fzw-mr1       -R7077:localhost:7077 -gfCN -T -e none; }
function verify_fwd02_7077() { test_port localhost 20024; }
function test_port() { nc -zv $1 $2 2>&1 | grep -sq succeeded; }
function run_job() {
    if [ ${#@} -eq 0 ]; then return; fi
    local job=$1
    local title=${2:-${job}}
    if do_and_verify \
        "verify_${job}" \
        "start_${job}" \
        "sleep 5"; then true \
     && log_info "\"${HOST_NAME_s}\": Successfully ${title}!" \
     && true; \
    else true \
     && log_error "\"${HOST_NAME_s}\": Fail to ${title}" \
     && false; \
    fi
}
function main() {
    true \
 && if true; then true \
     && run_job socks_7077 "start self proxy at 7077" \
     && run_job socks_7070 "start tunnel to seu at 7070" \
     && run_job socks_7071 "start tunnel to gfw at 7071" \
     && true; \
    fi \
 && if [ "$HOST_NAME_s" == "blahome" ]; then true \
     && run_job socks_7072 "start tunnel to bj office at 7072" \
     && true; \
    fi \
 && if [ "$HOST_NAME_s" == "bladesk1" ]; then true \
     && run_job fwd01_7077 "forward 7077 to bj-209-20-22" \
     && run_job fwd02_7077 "forward 7077 to bj-209-20-22-fzw-mr1" \
     && true; \
    fi \
 && true; \
}


main $@
