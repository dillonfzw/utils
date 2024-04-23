

if [[ $- == *i* ]]; then is_interactive_shell=true; else is_interactive_shell=false; fi
if shopt -q login_shell; then is_login_shell=true; else is_login_shell=false; fi


alias k='kubectl'
alias kcd='kubectl config set-context $(kubectl config current-context) --namespace'


HOSTNAME_s=`hostname -s`
if [ ${USER:-`whoami`} != "root" ]; then _sudo=${_sudo:-/usr/bin/sudo}; fi


#
# PDSH cluster variables
#
export PDSH_RCMD_TYPE=ssh
export WCOLL=~/.ssh/wcoll
export PDSH_GENDERS_DIR=~/.ssh
export PDSH_GENDERS_FILE=~/.ssh/genders
export FANOUT=32
if true; then true \
 && if [ -n "${PDSH_SSH_ARGS_APPEND}" ]; then true \
     && alias ssh='ssh ${PDSH_SSH_ARGS_APPEND}' \
     && alias scp='scp ${PDSH_SSH_ARGS_APPEND}' \
     && alias sftp='sftp ${PDSH_SSH_ARGS_APPEND}' \
     && alias rsync='rsync -e "ssh ${PDSH_SSH_ARGS_APPEND}"' \
     && true; \
    fi \
 && true; \
fi


#
# WA host issue
#
if [ -f /.dockerenv ] && ! grep -sqF "${HOSTNAME_s}" /etc/hosts; then true \
 && ${_sudo} ${_sudo:+-n} bash -c "echo 127.0.0.1 ${HOSTNAME_s} >> /etc/hosts;" >/dev/null 2>&1 \
 && grep -sqF "${HOSTNAME_s}" /etc/hosts \
 && true; \
fi || echo "[W]: Fail to workaround hostname issue in hostfile" >&2; \


#
# python venv variables
#
export PYVER=${PYVER:-3}
export WORKON_HOME=${WORKON_HOME:-~/.venvs}
export VIRTUALENV_PYTHON=`command -v python${PYVER:-3}`
export VIRTUALENVWRAPPER_PYTHON=${VIRTUALENVWRAPPER_PYTHON:-`command -v python3.8`}
source /usr/share/virtualenvwrapper/virtualenvwrapper_lazy.sh


#
# Iluvatar variables
#
export IXDEBUGGER_PATH=${IXDEBUGGER_PATH:-~/workspace/ixcollect/ixdebugger_bins/ubuntu/18.04/ixdebuger}
export COREX_HOME=${COREX_HOME:-/usr/local/corex}
if [ -n "`ls -1 /dev/aip_bi* /dev/iluvatar* 2>/dev/null | xargs`" -o \
     `lspci -n 2>/dev/null | grep 1e3e | wc -l` -gt 0 ]; then true \
 && true "Activate corex env only if there is kmd loaded or pci device detected" \
 && if [ -f ~/bin/corex.sh ] && source ~/bin/corex.sh; then true; \
    elif command -v corex.sh >/dev/null 2>&1 && source corex.sh; then true; \
    else echo "[W]: Fail to source Iluvatar SDK env script: \"corex.sh\"!" >&2; false; fi \
 && true; \
fi


#
# enforce limits
#
ulimit -n 102400
# nccl/ixccl needs extend -l limit or you have to use root to run workload
if ! ulimit -l unlimited; then true \
 && echo -e 'root - memlock -1\n* - memlock -1' | ${_sudo} ${_sudo:+-n} tee /etc/security/limits.d/nccl_memlock.conf \
 && true; \
fi


#
# house clean
#
