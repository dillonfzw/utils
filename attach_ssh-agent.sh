#! /bin/bash

[ -n "$USER" ] || USER=`whoami`
[ -n "$SSH_AGENT_CONF" ] || SSH_AGENT_CONF=~/.ssh-agent

# rt
# NOTE: assume agents uses default socket path
function get_ssh_agent_sockets() {
    # /tmp/ssh-*/agent.*              <== ssh-agent, native or forwarded
    # /run/user/`id -u`/keyring/ssh   <== gnome-keyring
    ls -1 /tmp/ssh-*/agent.* /run/user/`id -u`/keyring/ssh 2>/dev/null | xargs
}
# get the agend pid from native agent socket
# NOTE: only work for Linux procfs
function get_ssh_agent_pid() {
    local agent_socket=$1

    local agent_pids=`pidof ssh-agent`
    [ -n "$agent_pids" ] && \
    agent_pids=`ps -o pid,user -p $agent_pids 2>/dev/null | \
        grep -w $USER | awk '{print $1}'`

    local rc=1
    [ -n "$agent_pids" ] && \
    for agent_pid in $agent_pids
    do
        if grep -sqwF "$agent_socket" /proc/$agent_pid/net/unix; then
            echo $agent_pid
            rc=0
            break
        fi
    done

    return $rc
}
# test connection to the agent
function test_ssh_agent() {
    local agent_conf=$1
    # test the agent
    bash -c 'f='$agent_conf';
    if [ -S "$f" ]; then
        export SSH_AUTH_SOCK="$f";
    else
        source $f;
    fi;
    line="$(ssh-add -l 2>&1)";
    rc=$?;
    echo "$line";
    if [ $rc -ne 0 ] && ! echo "$line" | grep -sq "The agent has no identities"; then
        false;
    fi' >/dev/null
}
# rt
function create_ssh_agent_profile() {
    local agent_socket=$1

    if test_ssh_agent $agent_socket; then
        echo "SSH_AUTH_SOCK=$agent_socket; export SSH_AUTH_SOCK;"

        # get agent's pid
        local agent_pid=`get_ssh_agent_pid $agent_socket`

        if [ -n "$agent_pid" ]; then
            echo "SSH_AGENT_PID=$agent_pid; export SSH_AGENT_PID;"
            echo "echo Agent pid $agent_pid;"
        fi
    else
        false
    fi
}
# traverse agent sockets to pick a valid one
function validate_ssh_agent_sockets() {
    local rc=1
    local ftmp=""

    # traverse agent sockets
    for agent_socket in `get_ssh_agent_sockets`
    do
        # it must be a writeable socket
        [ -S $agent_socket -a -w $agent_socket ] || continue

        # create agent profile
        [ -n "$ftmp" -a -f "$ftmp" ] && rm -f $ftmp
        ftmp=`mktemp /tmp/ssh-agent.conf.XXXX` && \
        create_ssh_agent_profile $agent_socket >$ftmp && \

        # test and set agent conf
        if test_ssh_agent $ftmp >/dev/null 2>&1; then
            echo $agent_socket $agent_pid
            rc=0
            break
        fi
    done
    [ -n "$ftmp" -a -f "$ftmp" ] && rm -f $ftmp

    return $rc
}

# main
# attach agent if no valid agent connection
! ssh-add -l >/dev/null 2>&1 && \
if [ ! -f $SSH_AGENT_CONF ] || ! test_ssh_agent $SSH_AGENT_CONF; then
    agent_socket=`validate_ssh_agent_sockets` && \
    create_ssh_agent_profile $agent_socket >$SSH_AGENT_CONF
fi &&
echo "Source SSH_AGENT_CONF \"$SSH_AGENT_CONF\"" && \
source $SSH_AGENT_CONF
