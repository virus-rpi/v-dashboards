module main

import net.http
import json
import os

fn get_authenticated_github(url string, token string) ?http.Response {
	mut req := http.new_request(http.Method.get, url, '')
	req.add_header(http.CommonHeader.authorization, 'token ' + token)
	return req.do()!
}

const go2v_repo_api_url = 'https://api.github.com/repos/vlang/go2v/contents/'

struct TestResult {
	name   string
	passed bool
}

struct TotalTestStats {
mut:
	total_tests  int
	total_failed int
	results      []TestResult
}

struct GitHubContent {
	name         string
	path         string
	content_type string @[json: 'type']
}

fn analyze_go2v_tests() !TotalTestStats {
	mut stats := TotalTestStats{}
	mut results := []TestResult{}

	branch := 'master'
	token := os.getenv('GITHUB_TOKEN')

	// Listing the tests directory from the go2v repository (passed tests)
	tests_url := '${go2v_repo_api_url}tests?ref=${branch}'
	resp_tests := get_authenticated_github(tests_url, token) or {
		return error('failed to get tests directory')
	}
	if resp_tests.status_code == 200 {
		contents := json.decode([]GitHubContent, resp_tests.body) or { []GitHubContent{} }
		for item in contents {
			if item.content_type == 'dir' {
				stats.total_tests++
				results << TestResult{
					name:   item.name
					passed: true
				}
			}
		}
	}

	// Listing the untested directory from the go2v repository (failed tests)
	untested_url := '${go2v_repo_api_url}untested?ref=${branch}'
	resp_untested := get_authenticated_github(untested_url, token) or {
		return error('failed to get untested directory')
	}
	if resp_untested.status_code == 200 {
		contents := json.decode([]GitHubContent, resp_untested.body) or { []GitHubContent{} }
		for item in contents {
			if item.content_type == 'dir' {
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

struct Go2V {
	stats TotalTestStats
}

fn Go2V.new() Go2V {
	return Go2V{
		stats: analyze_go2v_tests() or { return Go2V{} }
	}
}

fn (_ Go2V) get_title() string {
	return 'Go2V Tests'
}

fn (_ Go2V) get_full_page_link() string {
	return 'go2v'
}

fn (go_2_v Go2V) get_content() string {
	stats := go_2_v.stats

	total_tests, total_failed := stats.total_tests, stats.total_failed
	overall_successful := if total_tests > 0 {
		100.0 - (f64(total_failed) * 100.0 / f64(total_tests))
	} else {
		100.0
	}

	return '
        <style>
            .go2v-progress-outer {width:100%; background-color:#333; height:20px; border-radius:4px; margin:10px 0;}
            @keyframes fillGo2V {0% {width: 0%;} 100% {width: ${overall_successful}%;}}
            .go2v-progress-inner {animation: fillGo2V 0.7s ease-in-out forwards; background-color:#4CAF50; height:100%; border-radius:4px; display: flex; align-items: center; justify-content: center;}
            @keyframes fadeGo2V {0% {opacity: 0;} 100% {opacity: 1;}}
            .go2v-progress-label {animation: fadeGo2V 0.7s ease-in-out forwards;}
        </style>
        <p>Total tests: <span id="total_tests">0</span></p>
        <p>Total failed tests: <span id="total_failed">0</span></p>
        <p>Overall successful: </p>
        <div class="go2v-progress-outer">
          <div class="go2v-progress-inner" style="width: ${overall_successful}%;"><span id="go2v-progress-label" class="go2v-progress-label">0.00%</span></div>
        </div>
        <script>
            document.addEventListener("DOMContentLoaded", function() {
              animatePercentageValue("go2v-progress-label", 0, ${overall_successful}, 700);
  			  animateValue("total_tests", 0, ${total_tests}, 700);
              animateValue("total_failed", 0, ${total_failed}, 700);
			});
        </script>
        '
}

fn (go_2_v Go2V) get_full_page_content() string {
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
	for res in go_2_v.stats.results {
		status_class := if res.passed { 'pass' } else { 'fail' }
		status_text := if res.passed { 'Passed' } else { 'Failed' }
		table += '<tr><td>${res.name}</td><td class="${status_class}">${status_text}</td></tr>'
	}
	table += '
	  </tbody>
	</table>
	'
	return go_2_v.get_content() + table
}
