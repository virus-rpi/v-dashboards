module main

import net.http
import json
import os

struct GitHubIssue {
	body     string
	title    string @[json: 'title']
	html_url string @[json: 'html_url']
}

struct UIRoadmap {
	title            string
	full_page_link   string
	progress         f64
	completed_tasks  []string
	incomplete_tasks []string
	categories       map[string][]string
}

fn get_authenticated_issue(issue_url string, token string) ?http.Response {
	mut req := http.new_request(http.Method.get, issue_url, '')
	req.add_header(http.CommonHeader.authorization, 'token ' + token)
	return req.do()!
}

fn UIRoadmap.new() UIRoadmap {
	issue_url := 'https://api.github.com/repos/vlang/ui/issues/31'
	token := os.getenv('GITHUB_TOKEN')
	resp := get_authenticated_issue(issue_url, token) or {
		println('Failed to get issue')
		return UIRoadmap{}
	}
	if resp.status_code != 200 {
		println('Failed to get issue')
		println(resp.body)
		return UIRoadmap{}
	}
	issue := json.decode(GitHubIssue, resp.body) or { return UIRoadmap{} }
	progress, completed_tasks, incomplete_tasks, categories := calculate_progress(issue.body)
	return UIRoadmap{
		title:            'UI Lib v0.1 Release Progress'
		full_page_link:   'ui-release-progress'
		progress:         progress
		completed_tasks:  completed_tasks
		incomplete_tasks: incomplete_tasks
		categories:       categories
	}
}

fn (ui UIRoadmap) get_title() string {
	return ui.title
}

fn (ui UIRoadmap) get_full_page_link() string {
	return ui.full_page_link
}

fn (ui UIRoadmap) get_content() string {
	return '
        <style>
            .ui-roadmap-progress-outer {width:100%; background-color:#333; height:20px; border-radius:4px; margin:10px 0;}
            @keyframes fillUIRoadmap {0% {width: 0%;} 100% {width: ${ui.progress}%;}}
            .ui-roadmap-progress-inner {animation: fillUIRoadmap 0.7s ease-in-out forwards; background-color:#4CAF50; height:100%; border-radius:4px; display: flex; align-items: center; justify-content: center;}
            @keyframes fadeUIRoadmap {0% {opacity: 0;} 100% {opacity: 1;}}
            .ui-roadmap-progress-label {animation: fadeUIRoadmap 0.7s ease-in-out forwards;}
        </style>
        <p>Total tasks: <span id="total-counter">0</span></p>
        <p>Total completed tasks: <span id="completed-counter">0</span></p>
        <p>Total incomplete tasks: <span id="incomplete-counter">0</span></p>
        <p>Roadmap progress:</p>
        <div class="ui-roadmap-progress-outer">
          <div class="ui-roadmap-progress-inner" style="width: ${ui.progress}%;"><span id="ui-progress-label">0.00%</span></div>
        </div>
        <script>
            document.addEventListener("DOMContentLoaded", function(){
            	animatePercentageValue("ui-progress-label", 0, ${ui.progress}, 700);
            	animateValue("total-counter", 0, ${
		ui.completed_tasks.len + ui.incomplete_tasks.len}, 700);
				animateValue("completed-counter", 0, ${ui.completed_tasks.len}, 700);
                animateValue("incomplete-counter", 0, ${ui.incomplete_tasks.len}, 700);
            });
        </script>
    '
}

fn (ui UIRoadmap) get_full_page_content() string {
	mut content := ui.get_content()

	style := '
    <style>
      table {
        width: 100%;
        border-collapse: collapse;
        table-layout: fixed;
        margin-top: 10px;
        margin-bottom: 20px;
      }
      th, td {
        border: 1px solid #444;
        padding: 8px;
        text-align: left;
      }
      th {
        background: #1e1e1e;
        color: #fff;
      }
      table td:nth-child(1) {
        background-color: #F44336;
      }
      table td:nth-child(2) {
        background-color: #4CAF50;
      }
    </style>
    '
	content += style

	for category, tasks in ui.categories {
		content += '<h2>' + category + '</h2>'
		mut comp_tasks := []string{}
		mut incomp_tasks := []string{}
		for t in tasks {
			if t in ui.completed_tasks {
				comp_tasks << t
			} else if t in ui.incomplete_tasks {
				incomp_tasks << t
			}
		}
		max_rows := if comp_tasks.len > incomp_tasks.len { comp_tasks.len } else { incomp_tasks.len }
		mut table_html := '<table>'
		table_html += '<thead><tr><th>Incomplete</th><th>Completed</th></tr></thead>'
		table_html += '<tbody>'
		for i in 0 .. max_rows {
			incomplete_point := if i < incomp_tasks.len { incomp_tasks[i] } else { '' }
			completed_point := if i < comp_tasks.len { comp_tasks[i] } else { '' }
			table_html += '<tr><td>' + incomplete_point + '</td><td>' + completed_point +
				'</td></tr>'
		}
		table_html += '</tbody></table>'
		content += table_html
	}
	return content
}

fn calculate_progress(issue_body string) (f64, []string, []string, map[string][]string) {
	mut total, mut completed := 0, 0
	mut completed_tasks := []string{}
	mut incomplete_tasks := []string{}
	mut categoies := map[string][]string{}

	lines := issue_body.split('\n')
	mut current_category := 'Uncategorized'
	for line in lines {
		if line.starts_with('##') {
			category := line[3..].trim_space()
			if category !in categoies {
				categoies[category] = []
			}
			current_category = category
		}
		if line.contains('[x]') {
			completed++
			completed_tasks << line.substr_ni(6, -1).replace('_(@thecodrr)_', '').replace('_(@memeone)_',
				'')
			categoies[current_category] << line.substr_ni(6, -1).replace('_(@thecodrr)_',
				'').replace('_(@memeone)_', '')
		} else if line.contains('[ ]') {
			incomplete_tasks << line.substr_ni(6, -1).replace('_(@thecodrr)_', '').replace('_(@memeone)_',
				'')
			categoies[current_category] << line.substr_ni(6, -1).replace('_(@thecodrr)_',
				'').replace('_(@memeone)_', '')
		}
		total++
	}

	mut progress := 0.0
	if total > 0 {
		progress = (f64(completed) / f64(total)) * 100.0
	}
	return progress, completed_tasks, incomplete_tasks, categoies
}
