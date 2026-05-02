def compare_files(actual, expected):
    try:
        with open(actual) as a, open(expected) as e:
            a_lines = a.readlines()
            e_lines = e.readlines()

        missing = [line for line in e_lines if line not in a_lines]
        extra = [line for line in a_lines if line not in e_lines]

        return {
            "pass": len(missing) == 0 and len(extra) == 0,
            "missing_lines": missing,
            "extra_lines": extra
        }

    except FileNotFoundError:
        return {
            "pass": False,
            "error": "Output file not generated (no subtitles found)"
        }