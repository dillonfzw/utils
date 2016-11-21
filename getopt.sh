# import cmd line arguments
for item in $@
do
    if [ "$item" = "--" ]; then
        shift
        bench_args="$@"
        break

    elif [ "$item" = "-h" -o "$item" = "--help" ]; then
        usage
        exit 0

    elif [ "$item" = "-v" -o "$item" = "--version" ]; then
        echo "$PROGVERSION"
        exit 0

    elif echo "$item" | grep -sq "^-"; then 
        shift
        continue

    elif echo "$item" | grep -sq "="; then
        key=`echo "$item" | cut -d= -f1 -`
        val=`echo "$item" | cut -d= -f2- -`
        [ -n "$val" ] || val=true
        eval "$key=\"$val\""

    else
        eval "$item=true"
    fi  
    shift
done

# Initialize the default value for each variable in the OPTMAPS
declare entry=""
for nvar in `set | grep "^DEFAULT_.*=" | cut -d= -f1 | sed -e 's/^DEFAULT_//g' | xargs`
do
    if [ -n "$nvar" ] &&
       eval "[ -n \"\$DEFAULT_$nvar\" ]"; then
        eval "\
        if [ -z \"\$$nvar\" ]; then \
            $nvar=\$DEFAULT_$nvar; \
            [ \"$nvar\" != \"verbose\" ] && \
            log_debug \"Default variable \\\"$nvar\\\" to \\\"\$$nvar\\\".\"; \
        fi;"

        # replace log_debug to fake function if not verbose.
        if [ "$nvar" = "verbose" ] && ! $verbose; then
            eval "function log_debug { true; }"
        fi
    fi
done

