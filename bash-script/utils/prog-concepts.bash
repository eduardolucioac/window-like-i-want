function f_validate_n_set() {
    : 'Check a set of key/value arguments against a declaration, and apply them.

    $1 - name of a read-only associative array declaring the valid attributes.
         Its keys are the attribute names and its values the defaults; a key
         prefixed with "!" marks the attribute as required.
    $2 - name of the associative array to fill in.
    $3+ - the attributes themselves, as alternating names and values.

    Returns 1 on an odd number of arguments, an unknown attribute, or a
    required attribute that was not passed.

    NOTE: An attribute counts as passed even when its value is the empty
    string, which is deliberate: "" is a legitimate value for several of them.
    '

    local valid_attrs_name=$1
    local -n valid_attrs_value=$1
    local -n data_content="$2"
    shift 2

    if (( "$#" % 2 != 0 )); then
        echo "ERROR: Incomplete key-value pair detected!"
        return 1
    fi

    local -A attributes_to_set
    local key
    local value
    while (( "$#" )); do
        key="$1"
        value="$2"
        shift 2
        if [[ -v valid_attrs_value["$key"] ]] || [[ -v valid_attrs_value["!$key"] ]] ; then
            attributes_to_set["$key"]="$value"
        else
            echo "ERROR! The attribute \"$key\" is invalid as defined in \"$valid_attrs_name\" \
and will be ignored!"
            return 1
        fi
    done

    local current_key
    local is_required
    for key in "${!valid_attrs_value[@]}"; do

        is_required=0
        if [[ "$key" == !* ]]; then
            current_key="${key#!}"
            is_required=1
        else
            current_key="$key"
        fi

        if [[ -v "attributes_to_set[$current_key]" ]]; then
            data_content["$current_key"]="${attributes_to_set[$current_key]}"
        elif [ ${is_required} -eq 1 ]; then
            echo "ERROR! The attribute \"$current_key\" is required as defined in \"$valid_attrs_name\"!"
            return 1
        else
            data_content["$current_key"]="${valid_attrs_value[$key]}"
        fi

    done
}

function f_class_constructor() {
    : 'Build an object: the constructor half of "f_validate_n_set".

    Same arguments. The name exists to say, at the call site, that what is
    being filled in is the state of a new object.
    '

    f_validate_n_set "$@"
}

function f_function_signature() {
    : 'Read named arguments: the call half of "f_validate_n_set".

    Same arguments. The name exists to say, at the call site, that what is
    being checked is the arguments of a call rather than the state of a new
    object.
    '

    f_validate_n_set "$@"
}

