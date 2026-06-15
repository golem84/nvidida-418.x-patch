#!/usr/bin/env python3
"""
Generate conftest.h and related compile test files for NVIDIA 418.113 driver.

This script runs all compile tests against the target kernel headers and generates
the conftest configuration files that the driver uses to detect kernel API availability.

Usage:
    cd NVIDIA-Linux-x86_64-418.113/kernel
    python3 ../../scripts/generate_conftest.py

Requirements:
    - conftest.sh must be executable
    - Kernel headers must be installed at /usr/src/linux-headers-7.0.0-22 and
      /usr/src/linux-headers-7.0.0-22-generic
"""

import subprocess
import os
import re

def main():
    # Используем текущую директорию (ожидается, что скрипт запущен из kernel/)
    # Если запущен из scripts/, поднимаемся на уровень выше в kernel/
    script_dir = os.path.dirname(os.path.abspath(__file__))
    if os.path.basename(os.getcwd()) == 'scripts':
        os.chdir('..')
    elif os.path.basename(os.getcwd()) != 'kernel':
        # Пытаемся найти kernel/ относительно скрипта
        kernel_dir = os.path.join(script_dir, '..', 'NVIDIA-Linux-x86_64-418.113', 'kernel')
        if os.path.isdir(kernel_dir):
            os.chdir(kernel_dir)

    # Get CFLAGS
    print("Getting CFLAGS from conftest.sh...")
    result = subprocess.run([
        './conftest.sh', 'gcc', 'gcc', 'x86_64',
        '/usr/src/linux-headers-7.0.0-22',
        '/usr/src/linux-headers-7.0.0-22-generic',
        'build_cflags'
    ], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    cflags = result.stdout.strip()
    if not cflags:
        print("ERROR: Failed to get CFLAGS")
        return 1

    print(f"Got CFLAGS (length {len(cflags)})")

    # Read Kbuild to get the list of compile tests
    with open('Kbuild', 'r') as f:
        kbuild_content = f.read()

    # Extract all compile test types
    def extract_tests(pattern, content):
        lines = content.split('\n')
        tests = []
        in_section = False
        for line in lines:
            if pattern in line:
                in_section = True
                parts = line.split('?=')
                if len(parts) > 1:
                    rest = parts[1].strip().replace('\\', '')
                    for word in rest.split():
                        if re.match(r'^[a-z_][a-z0-9_]*$', word):
                            tests.append(word)
            elif in_section:
                if line.strip().startswith('NV_CONFTEST_') or line.strip().startswith('$(eval'):
                    break
                test = line.strip().replace('\\', '').strip()
                if test and re.match(r'^[a-z_][a-z0-9_]*$', test):
                    tests.append(test)
        return tests

    func_tests = extract_tests('NV_CONFTEST_FUNCTION_COMPILE_TESTS', kbuild_content)
    generic_tests = extract_tests('NV_CONFTEST_GENERIC_COMPILE_TESTS', kbuild_content)
    macro_tests = extract_tests('NV_CONFTEST_MACRO_COMPILE_TESTS', kbuild_content)
    symbol_tests = extract_tests('NV_CONFTEST_SYMBOL_COMPILE_TESTS', kbuild_content)
    type_tests = extract_tests('NV_CONFTEST_TYPE_COMPILE_TESTS', kbuild_content)

    # Create directories
    os.makedirs('conftest/compile-tests', exist_ok=True)

    # Run all compile tests
    all_tests = func_tests + generic_tests + macro_tests + symbol_tests + type_tests
    print(f"Running {len(all_tests)} compile tests...")

    for i, test in enumerate(all_tests):
        result = subprocess.run([
            './conftest.sh', 'gcc', 'gcc', 'x86_64',
            '/usr/src/linux-headers-7.0.0-22',
            '/usr/src/linux-headers-7.0.0-22-generic',
            'compile_tests', cflags, test
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        
        filepath = f'conftest/compile-tests/{test}.h'
        with open(filepath, 'w') as f:
            f.write(result.stdout)
        
        # Debug: print stderr if non-empty
        if result.stderr:
            print(f"  {test}: stderr: {result.stderr}")
        
        if i % 50 == 0:
            print(f"  Progress: {i}/{len(all_tests)}")

    # Generate concatenated headers
    def concat_tests(test_list, output_file):
        content = ''
        for test in test_list:
            filepath = f'conftest/compile-tests/{test}.h'
            if os.path.exists(filepath):
                with open(filepath, 'r') as f:
                    data = f.read()
                    print(f"  Reading {test}: {repr(data)}")  # Debug
                    content += data
            else:
                print(f"  WARNING: {test} file not found at {filepath}")  # Debug
        print(f"  Writing {output_file} with length {len(content)}")  # Debug
        with open(output_file, 'w') as f:
            f.write(content)

    concat_tests(func_tests, 'conftest/functions.h')
    concat_tests(generic_tests, 'conftest/generic.h')
    concat_tests(macro_tests, 'conftest/macros.h')
    concat_tests(symbol_tests, 'conftest/symbols.h')
    concat_tests(type_tests, 'conftest/types.h')

    # Generate headers.h
    print("Generating headers.h...")
    result = subprocess.run([
        './conftest.sh', 'gcc', 'gcc', 'x86_64',
        '/usr/src/linux-headers-7.0.0-22',
        '/usr/src/linux-headers-7.0.0-22-generic',
        'test_kernel_headers'
    ], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    with open('conftest/headers.h', 'w') as f:
        f.write(result.stdout)

    # Generate conftest.h
    print("Generating conftest.h...")
    with open('conftest/conftest.h', 'w') as f:
        f.write('#ifndef _CONFTEST_H\n')
        f.write('#define _CONFTEST_H\n\n')
        f.write('#include "headers.h"\n')
        f.write('#include "functions.h"\n')
        f.write('#include "generic.h"\n')
        f.write('#include "macros.h"\n')
        f.write('#include "symbols.h"\n')
        f.write('#include "types.h"\n\n')
        f.write('#endif\n')

    print("Generated all conftest files successfully")

    # Verify key tests
    print("\nVerifying key tests:")
    for test in ['vmf_insert_pfn', 'kmap_local_page', 'timer_setup', 'get_user_pages', 'get_user_pages_remote']:
        filepath = f'common/inc/conftest/compile-tests/{test}.h'
        if os.path.exists(filepath):
            with open(filepath, 'r') as f:
                content = f.read().strip()
                status = content if content else '(empty)'
                print(f"  {test}: {status}")
        else:
            print(f"  {test}: FILE NOT FOUND")

    return 0

if __name__ == '__main__':
    exit(main())
