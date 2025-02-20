#!/usr/bin/env python

import sys
import re

file_name = sys.argv[1]

test_comment_pattern = r"^\s*\/\/\s+(\d+.*)"
first_comment_pattern = r"^\s*\/\/\s+0+1"

test_plans = []
with open(file_name, "r") as f:
    test_plan = []
    for line in f.readlines():
        match = re.search(test_comment_pattern, line)
        if match:
            if re.search(first_comment_pattern, line) and test_plan:
                test_plans.append(test_plan)
                test_plan = []
            test_plan.append(match.group(1))
    if test_plan:
        test_plans.append(test_plan)

for plan in test_plans:
    print("/*\nTest Plan:\n")
    for line in plan:
        print(line)
    print("*/\n\n")
