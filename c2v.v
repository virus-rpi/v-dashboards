module main

import json
import os

const c2v_repo_api_url = 'https://api.github.com/repos/vlang/c2v/contents/'

fn analyze_c2v_tests() !TotalTestStats {
	mut stats := TotalTestStats{}
	mut results := []TestResult{}

	branch := 'master'
	token := os.getenv('GITHUB_TOKEN')

	// Listing the tests directory from the c2v repository (passed tests)
	tests_url := '${c2v_repo_api_url}tests?ref=${branch}'
	resp_tests := get_authenticated_github(tests_url, token) or {
		return error('failed to get tests directory')
	}
	if resp_tests.status_code == 200 {
		contents := json.decode([]GitHubContent, resp_tests.body) or { []GitHubContent{} }
		for item in contents {
			if item.name.ends_with('.c') {
				stats.total_tests++
				results << TestResult{
					name:   item.name
					passed: true
				}
			}
		}
	}

	// Listing the untested directory from the c2v repository (failed tests)
	untested_url := '${c2v_repo_api_url}tests_todo?ref=${branch}'
	resp_untested := get_authenticated_github(untested_url, token) or {
		return error('failed to get untested directory')
	}
	if resp_untested.status_code == 200 {
		contents := json.decode([]GitHubContent, resp_untested.body) or { []GitHubContent{} }
		for item in contents {
			if item.name.ends_with('.c') {
				stats.total_tests++
				stats.total_failed++
				results << TestResult{
					name:   item.name
					passed: false
				}
			}
		}
	}
	stats.results = results
	return stats
}

struct C2V {
	stats TotalTestStats
}

fn C2V.new() C2V {
	return C2V{
		stats: analyze_c2v_tests() or { return C2V{} }
	}
}

fn (_ C2V) get_title() string {
	return 'C2V Tests'
}

fn (_ C2V) get_full_page_link() string {
	return 'c2v'
}

fn (c_2_v C2V) get_content() string {
	stats := c_2_v.stats

	total_tests, total_failed := stats.total_tests, stats.total_failed
	overall_successful := if total_tests > 0 {
		100.0 - (f64(total_failed) * 100.0 / f64(total_tests))
	} else {
		100.0
	}

	return '
        <style>
            .c2v-progress-outer {width:100%; background-color:#333; height:20px; border-radius:4px; margin:10px 0;}
            @keyframes fillC2V {0% {width: 0%;} 100% {width: ${overall_successful}%;}}
            .c2v-progress-inner {animation: fillC2V 0.7s ease-in-out forwards; background-color:#4CAF50; height:100%; border-radius:4px; display: flex; align-items: center; justify-content: center;}
            @keyframes fadeC2V {0% {opacity: 0;} 100% {opacity: 1;}}
            .c2v-progress-label {animation: fadeC2V 0.7s ease-in-out forwards;}
        </style>
        <p>Total tests: <span id="c2v_total_tests">0</span></p>
        <p>Total failed tests: <span id="c2v_total_failed">0</span></p>
        <p>Overall successful: </p>
        <div class="c2v-progress-outer">
          <div class="c2v-progress-inner" style="width: ${overall_successful}%;"><span id="c2v-progress-label" class="c2v-progress-label">0.00%</span></div>
        </div>
        <script>
            document.addEventListener("DOMContentLoaded", function() {
              animatePercentageValue("c2v-progress-label", 0, ${overall_successful}, 700);
  			  animateValue("c2v_total_tests", 0, ${total_tests}, 700);
              animateValue("c2v_total_failed", 0, ${total_failed}, 700);
			});
        </script>
        '
}

fn (c_2_v C2V) get_full_page_content() string {
	mut table := '
	<style>
		table {width:100%; border-collapse:collapse; margin-top:20px;}
		th, td {border:1px solid #444; padding:8px; text-align:left;}
		th {background:#1e1e1e; color:#fff; cursor:pointer;}
		tr:nth-child(even){background:#222;}
		.pass {color:#4CAF50; font-weight:bold;}
		.fail {color:#F44336; font-weight:bold;}
	</style>
	<table id="testsTable">
	  <thead>
		<tr>
		  <th>Test Name</th>
		  <th>Status</th>
		</tr>
	  </thead>
	  <tbody>
	'
	for res in c_2_v.stats.results {
		status_class := if res.passed { 'pass' } else { 'fail' }
		status_text := if res.passed { 'Passed' } else { 'Failed' }
		table += '<tr><td>${res.name}</td><td class="${status_class}">${status_text}</td></tr>'
	}
	table += '
	  </tbody>
	</table>
	'
	return c_2_v.get_content() + table
}
