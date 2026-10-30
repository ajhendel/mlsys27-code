# Sourced (POSIX sh) by every binding build script, device and host family, right after the shebang.
# ANONLIB_BUILD_DEFINES="NAME=1,NAME2=3" (comma-separated, no spaces, no -D) becomes
# ANONLIB_BUILD_DEFINE_FLAGS="-D NAME=1 -D NAME2=3", which each script expands, unquoted, on its one
# `pixi run mojo build` line. Unset or empty: ANONLIB_BUILD_DEFINE_FLAGS is empty and the mojo argv is
# byte-identical to a build without this file. The output directory never depends on it.
# The older per-script variables (ANONLIB_EXTRA_DEFINES, ANONLIB_BUILD_EXTRA_DEFINES) keep working
# unchanged; this is the one variable that reaches every binding (the grid passes it through lq:
# tools/six_lane_grid_lq.md).
ANONLIB_BUILD_DEFINE_FLAGS=
if [ -n "${ANONLIB_BUILD_DEFINES:-}" ]; then
    _mlbd_rest=$ANONLIB_BUILD_DEFINES
    while [ -n "$_mlbd_rest" ]; do
        case $_mlbd_rest in
            *,*) _mlbd_one=${_mlbd_rest%%,*}; _mlbd_rest=${_mlbd_rest#*,} ;;
            *) _mlbd_one=$_mlbd_rest; _mlbd_rest= ;;
        esac
        case $_mlbd_one in
            '') continue ;;
            -* | =* | *[!A-Za-z0-9_=.+-]*)
                echo "error: ANONLIB_BUILD_DEFINES entry '$_mlbd_one' is not NAME or NAME=VALUE" \
                     "(comma-separated, no spaces, no -D)" >&2
                exit 2 ;;
        esac
        ANONLIB_BUILD_DEFINE_FLAGS="$ANONLIB_BUILD_DEFINE_FLAGS -D $_mlbd_one"
    done
    ANONLIB_BUILD_DEFINE_FLAGS=${ANONLIB_BUILD_DEFINE_FLAGS# }
    unset _mlbd_rest _mlbd_one
fi
