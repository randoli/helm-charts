{{- define "vector.randoliTags.transform" -}}
extract_runtime_exceptions:
  type: remap
  inputs:
    - extract_trace_from_text
  source: |

    msg = "";  
    if is_string(.message) {
      msg = string!(.message)
    } else if is_object(.message) && exists(.message.message) &&
    is_string(.message.message) {
      msg = string!(.message.message)
    }

    if msg != "" {
      .randoli_tags = [];
      exception_data = null;

      if match(msg, r'^panic:\s') || match(msg, r'^fatal error:') {

        # golang panic
        is_crashed = false;
        exit = parse_regex!(msg, r'exit status (?P<code>\d+)');
        if exit.code != 0 {
          is_crashed = true
        }
        if match(msg, r'^panic:\s') && (contains(msg, "goroutine") || match(msg, r'\.go:\d+')) {
          panic_msg = parse_regex!(msg, r'^panic:\s*(?P<panic_error>.+)')
          exception_data = {
            "error.kind": "panic",
            "error.type": panic_msg.panic_error,
            "error.is_crashed": is_crashed,
            "runtime": "Go"
          }

        } else if match(msg, r'^fatal error:') {
          fatal_msg = parse_regex!(msg, r'^fatal error:\s*(?P<fatal_error>.+)')
          exception_data = {
            "error.kind": "fatal",
            "error.type": fatal_msg.fatal_error,
            "error.is_crashed": is_crashed,
            "runtime": "Go"
          }
        }
      } else if match(msg, r'^Traceback \(most recent call last\):') {

        # python traceback
        parsed = parse_regex(
          msg,
          r'Traceback .*?\n(?:.*\n)*?(?P<exception_type>[A-Za-z_][A-Za-z0-9_.]*):'
        ) ?? {}

        if parsed.exception_type != null {
          exception_data = {
            "runtime": "Python",
            "error.kind": "exception",
            "error.type": parsed.exception_type,
            "error.has_traceback": true
          }

        }
      } else if match(msg, r'Exception in thread') || match(msg, r'(?m)^[a-zA-Z0-9_.]+(Exception|Error):') {

        # java exception
        parsed = parse_regex(
          msg,
          r'(?m)^(?:Exception in thread "[^"]+" )?(?:[a-zA-Z0-9_.]+\.)?(?P<exception_type>[A-Za-z0-9_]+(Exception|Error))'
        ) ?? {}

        if parsed.exception_type != null {
          exception_data = {
            "error.kind": "exception",
            "error.type": parsed.exception_type,
            "runtime": "Java"
          }
        }
      }

      if exception_data != null {
        .randoli_tags = push(.randoli_tags, {
          "type": "EXCEPTION",
          "data": exception_data
        })
      }
    }
{{- end -}}