# import cmd line arguments
for _item_ieh7ef4och in $@
do
    if [ "$_item_ieh7ef4och" = "--" ]; then
        shift
        break

    elif [ "$_item_ieh7ef4och" = "-h" -o "$_item_ieh7ef4och" = "--help" ]; then
        usage
        exit 0

    elif [ "$_item_ieh7ef4och" = "-v" -o "$_item_ieh7ef4och" = "--version" ]; then
        echo "$PROGVERSION"
        exit 0

    elif echo "$_item_ieh7ef4och" | grep -sq "^-"; then 
        shift
        continue

    elif echo "$_item_ieh7ef4och" | grep -sq "="; then
        _key_aixooNae4e=`echo "$_item_ieh7ef4och" | cut -d= -f1 -`
        _val_aixooNae4e=`echo "$_item_ieh7ef4och" | cut -d= -f2- -`
        [ -n "$_val_aixooNae4e" ] || _val_aixooNae4e=true
        eval "$_key_aixooNae4e=\"$_val_aixooNae4e\""

    else
        eval "$_item_ieh7ef4och=true"
    fi  
    shift
done
unset _key_aixooNae4e
unset _val_aixooNae4e
unset _item_ieh7ef4och

# Initialize the default value for each variable in the OPTMAPS
for _nvar_thi3ahh3eR in `set | grep "^DEFAULT_.*=" | cut -d= -f1 | sed -e 's/^DEFAULT_//g' | xargs`
do
    if [ -n "$_nvar_thi3ahh3eR" ] &&
       eval "[ -n \"\$DEFAULT_$_nvar_thi3ahh3eR\" ]"; then
        eval "\
        if [ -z \"\$$_nvar_thi3ahh3eR\" ]; then \
            if declare -p DEFAULT_$_nvar_thi3ahh3eR | awk '{print \$2}' | grep -sq a; then \
                $_nvar_thi3ahh3eR=(\${DEFAULT_${_nvar_thi3ahh3eR}[@]}); \
            else \
                $_nvar_thi3ahh3eR=\$DEFAULT_$_nvar_thi3ahh3eR; \
            fi; \
            [ \"$_nvar_thi3ahh3eR\" != \"verbose\" ] && \
            declare -p $_nvar_thi3ahh3eR | sed -e 's/^/Default variable: /g' | log_lines debug; \
        fi;"
    fi
done
unset _nvar_thi3ahh3eR

# hook for set_log_level
if [ -n "$LOG_LEVEL" ] && declare -f set_log_level >/dev/null; then
    set_log_level $LOG_LEVEL
fi
