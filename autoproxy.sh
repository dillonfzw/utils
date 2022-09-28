#! /usr/bin/env bash


source ~/bin/log.sh
source ~/bin/utils.sh


function test_port() {
    nc -zv $1 $2 2>&1 | grep -sq succeeded
}
function start_socks_7070() { autossh -M 20010 -f seulogin -D7070 -gfCN -t -e none; }
function start_socks_7071() { autossh -M 20012 -f fuzwvps1 -D7071 -gfCN -t -e none -o 'ProxyCommand nc -x localhost:7070 %h %p'; }
function start_socks_7077() { autossh -M 20020 -f localhost -D7077 -gfCN -t -e none; }


if ! do_and_verify \
    "test_port localhost 7077" \
    start_socks_7077 \
    "sleep 5"; then true \
 && log_error "Fail to start socks proxy at 7077" \
 && false; \
fi && \
if ! do_and_verify \
    "test_port localhost 7070" \
    start_socks_7070 \
    "sleep 5"; then true \
 && log_error "Fail to start socks proxy at 7070" \
 && false; \
fi && \
if ! do_and_verify \
    "test_port localhost 7071" \
    start_socks_7071 \
    "sleep 5"; then true \
 && log_error "Fail to start socks proxy at 7071" \
 && false; \
fi
