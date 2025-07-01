module main

import json
import os
import time
import net.http

const vlang_org_api_url = 'https://api.github.com/orgs/vlang/repos'

const cache_file = '.vlang_issues_cache.json'
const cache_ttl_seconds = 3600 // 1 hour

struct VLangIssuesCache {
	repo_issues []RepoIssues
	stats       VLangIssuesStats
	timestamp   i64
}

struct VLangRepo {
	name     string
	archived bool
	owner    struct {
		login string
	}
}

struct Issue {
	title string
	url   string
}

struct RepoIssues {
	repo_name     string
	owner_login   string
	open_count    int
	closed_count  int
	open_issues   []Issue
	closed_issues []Issue
}

struct VLangIssuesStats {
mut:
	total_open   int
	total_closed int
}

struct GitHubIssueSearchResult {
	total_count int
}

struct GitHubIssueSearchResponse {
	items []GitHubIssue
}

fn fetch_repo_issues(owner string, repo string, token string) !RepoIssues {
	base_url := 'https://api.github.com/search/issues?q=repo:${owner}/${repo}+is:issue'
	open_url := base_url + '+is:open'
	closed_url := base_url + '+is:closed'

	open_resp := get_authenticated_github(open_url, token) or {
		return error('Failed to fetch open issues for ${owner}/${repo}: ${err}')
	}
	closed_resp := get_authenticated_github(closed_url, token) or {
		return error('Failed to fetch closed issues for ${owner}/${repo}: ${err}')
	}

	open_data := json.decode(GitHubIssueSearchResult, open_resp.body)!
	closed_data := json.decode(GitHubIssueSearchResult, closed_resp.body)!

	open_issues := fetch_repo_issue_titles(owner, repo, token, 'open') or { []Issue{} }
	closed_issues := fetch_repo_issue_titles(owner, repo, token, 'closed') or { []Issue{} }

	return RepoIssues{
		repo_name:     repo
		owner_login:   owner
		open_count:    open_data.total_count
		closed_count:  closed_data.total_count
		open_issues:   open_issues
		closed_issues: closed_issues
	}
}

fn fetch_repo_issue_titles(owner string, repo string, token string, state string) ![]Issue {
	mut all_issues := []Issue{}
	mut page := 1

	for {
		query := 'repo:${owner}/${repo} is:issue is:${state}'
		form_data := {
			'q':        query
			'per_page': '100'
			'page':     page.str()
		}
		encoded_params := http.url_encode_form_data(form_data)

		url := 'https://api.github.com/search/issues?${encoded_params}'

		resp := get_authenticated_github(url, token) or {
			return error('Failed to fetch ${state} issues for ${owner}/${repo} page ${page}: ${err}')
		}

		result := json.decode(GitHubIssueSearchResponse, resp.body) or {
			eprintln('Failed to decode JSON for ${owner}/${repo} ${state} issues page ${page}: ${err}')
			eprintln('Raw response: ${resp.body}')
			return []Issue{}
		}

		if result.items.len == 0 {
			break
		}

		for issue in result.items {
			all_issues << Issue{
				title: issue.title
				url:   issue.html_url
			}
		}

		if result.items.len < 100 {
			break
		}
		page++
	}

	return all_issues
}

fn analyze_vlang_issues(token string) !([]RepoIssues, VLangIssuesStats) {
	if os.exists(cache_file) {
		cache_text := os.read_file(cache_file) or { '' }
		if cache_text != '' {
			cache := json.decode(VLangIssuesCache, cache_text) or { VLangIssuesCache{} }
			if cache.timestamp + cache_ttl_seconds * 1000 > time.now().unix_milli() {
				return cache.repo_issues, cache.stats
			}
		}
	}

	mut stats := VLangIssuesStats{}
	mut repo_issues := []RepoIssues{}

	resp := get_authenticated_github(vlang_org_api_url, token) or {
		return error('Failed to fetch VLang repositories: ${err}')
	}
	repos := json.decode([]VLangRepo, resp.body)!

	for repo in repos {
		if repo.archived {
			continue
		}
		issues := fetch_repo_issues(repo.owner.login, repo.name, token) or { continue }

		repo_issues << RepoIssues{
			repo_name:     repo.name
			owner_login:   repo.owner.login
			open_count:    issues.open_count
			closed_count:  issues.closed_count
			open_issues:   issues.open_issues
			closed_issues: issues.closed_issues
		}

		stats.total_open += issues.open_count
		stats.total_closed += issues.closed_count
	}

	cache := VLangIssuesCache{
		repo_issues: repo_issues
		stats:       stats
		timestamp:   time.now().unix_milli()
	}
	json_cache := json.encode(cache)
	os.write_file(cache_file, json_cache) or {}

	return repo_issues, stats
}

struct VIssues {
	stats       VLangIssuesStats
	repo_issues []RepoIssues
}

fn VIssues.new() VIssues {
	token := os.getenv('GITHUB_TOKEN')
	if token == '' {
		return VIssues{}
	}

	repo_issues, stats := analyze_vlang_issues(token) or { return VIssues{} }

	return VIssues{
		stats:       stats
		repo_issues: repo_issues
	}
}

fn (_ VIssues) get_title() string {
	return 'VLang Open vs Solved Issues'
}

fn (_ VIssues) get_full_page_link() string {
	return 'vlang-issues'
}

fn (card VIssues) get_content() string {
	open := card.stats.total_open
	closed := card.stats.total_closed
	total := open + closed
	open_percent := if total > 0 {
		f64(open) * 100.0 / f64(total)
	} else {
		0.0
	}
	closed_percent := 100.0 - open_percent

	return '
	<style>
		.vlang-progress-outer{width:100%;background:#333;height:20px;border-radius:4px;margin:10px 0;display:flex;overflow:hidden}.vlang-progress-inner{height:100%;color:#fff;font-weight:700;text-align:center;line-height:20px;white-space:nowrap;overflow:hidden}.vlang-closed{background:#4CAF50;animation:fillClosed .7s ease-in-out forwards;border-radius:4px 0 0 4px}.vlang-open{background:#F44336;animation:fillOpen .7s ease-in-out forwards;border-radius:0 4px 4px 0}@keyframes fillClosed{0%{width:0}100%{width:${closed_percent}%}}@keyframes fillOpen{0%{width:0}100%{width:${open_percent}%}}
	</style>
	<p>This card shows the ratio of open vs closed issues in all public VLang repositories.</p>
	<p>Total Issues: <span id="total_issues">0</span></p>
	<p>Open: <span id="open_issues">0</span>, Closed: <span id="closed_issues">0</span></p>
	<div class="vlang-progress-outer">
		<div class="vlang-progress-inner vlang-closed" style="width: ${closed_percent}%;">Closed</div>
		<div class="vlang-progress-inner vlang-open" style="width: ${open_percent}%;">Open</div>
	</div>
	<script>
		document.addEventListener("DOMContentLoaded", function() {
			animateValue("total_issues", 0, ${
		open + closed}, 700);
			animateValue("open_issues", 0, ${open}, 700);
			animateValue("closed_issues", 0, ${closed}, 700);
		});
	</script>
	'
}

fn (card VIssues) get_full_page_content() string {
	open := card.stats.total_open
	closed := card.stats.total_closed
	total := open + closed
	open_percent := if total > 0 {
		f64(open) * 100.0 / f64(total)
	} else {
		0.0
	}
	closed_percent := 100.0 - open_percent

	mut sorted_repos := card.repo_issues.clone()
	sorted_repos.sort_with_compare(fn (a &RepoIssues, b &RepoIssues) int {
		return a.repo_name.compare(b.repo_name)
	})

	mut open_table_rows := ''
	mut closed_table_rows := ''

	for repo in sorted_repos {
		repo_url := 'https://github.com/${repo.owner_login}/${repo.repo_name}'

		if repo.open_count > 0 {
			open_table_rows += '<tr class="expandable" data-repo="${repo.repo_name}_open">
				<td><a href="${repo_url}" target="_blank" rel="noopener noreferrer" class="issue-link">${repo.repo_name}</a></td>
				<td><a href="https://github.com/${repo.owner_login}/${repo.repo_name}/issues?q=is%3Aissue+is%3Aopen" class="issue-link" target="_blank" rel="noopener noreferrer">${repo.open_count}</a></td>
			</tr>
			<tr class="expandable-content" id="${repo.repo_name}_open" style="display:none;">
				<td colspan="2">
					<ul>
						${repo.open_issues.map(it.to_li()).join('\n')}
					</ul>
				</td>
			</tr>'
		}

		if repo.closed_count > 0 {
			closed_table_rows += '<tr class="expandable" data-repo="${repo.repo_name}_closed">
				<td><a href="${repo_url}" target="_blank" rel="noopener noreferrer" class="issue-link">${repo.repo_name}</a></td>
				<td><a href="https://github.com/${repo.owner_login}/${repo.repo_name}/issues?q=is%3Aissue+is%3Aclosed" class="issue-link" target="_blank" rel="noopener noreferrer">${repo.closed_count}</a></td>
			</tr>
			<tr class="expandable-content" id="${repo.repo_name}_closed" style="display:none;">
				<td colspan="2">
					<ul>
						${repo.closed_issues.map(it.to_li()).join('\n')}
					</ul>
				</td>
			</tr>'
		}
	}

	return '
	<style>
		.vlang-progress-outer{width:100%;background:#333;height:20px;border-radius:4px;margin:10px 0;display:flex;overflow:hidden}.vlang-progress-inner{height:100%;color:#fff;font-weight:700;text-align:center;line-height:20px;white-space:nowrap;overflow:hidden}.vlang-closed{background:#4CAF50;animation:fillClosed .7s ease-in-out forwards;border-radius:4px 0 0 4px}.vlang-open{background:#F44336;animation:fillOpen .7s ease-in-out forwards;border-radius:0 4px 4px 0}@keyframes fillClosed{0%{width:0}100%{width:${closed_percent}%}}@keyframes fillOpen{0%{width:0}100%{width:${open_percent}%}}.container{display:flex;gap:20px;margin-top:20px}table{width:100%;border-collapse:collapse;margin-top:10px}th,td{border:1px solid #444;padding:8px;text-align:left}th{background:#1e1e1e;color:#fff;cursor:pointer;user-select:none}tr:nth-child(even){background:#222}tr:hover{background-color:#333;cursor:pointer}.expandable-content ul{margin:0;padding-left:20px}.expandable-content li{margin-bottom:4px} .issue-link{color:#81d4fa;text-decoration:none;transition:text-decoration 0.2s ease-in-out}.issue-link:hover,.issue-link:focus{text-decoration:underline;color:#4fc3f7;outline:none}
	</style>


	<p>This page shows the ratio of open vs closed issues in all public VLang repositories.</p>
	<p>Total Issues: <span id="total_issues">0</span></p>
	<p>Open: <span id="open_issues">0</span>, Closed: <span id="closed_issues">0</span></p>
	<div class="vlang-progress-outer">
		<div class="vlang-progress-inner vlang-closed" style="width: ${closed_percent}%;">Closed</div>
		<div class="vlang-progress-inner vlang-open" style="width: ${open_percent}%;">Open</div>
	</div>

	<div class="container">
		<div style="flex:1;">
			<h2>Open Issues</h2>
			<table>
				<thead>
					<tr>
						<th>Repository</th>
						<th>Open Issues</th>
					</tr>
				</thead>
				<tbody>
					${open_table_rows}
				</tbody>
			</table>
		</div>
		<div style="flex:1;">
			<h2>Closed Issues</h2>
			<table>
				<thead>
					<tr>
						<th>Repository</th>
						<th>Closed Issues</th>
					</tr>
				</thead>
				<tbody>
					${closed_table_rows}
				</tbody>
			</table>
		</div>
	</div>

	<script>
		function toggleExpandableContent(id) {
			const el = document.getElementById(id);
			if (!el) return;
			el.style.display = (el.style.display === "table-row") ? "none" : "table-row";
		}

		document.addEventListener("DOMContentLoaded", function() {
			animateValue("total_issues", 0, ${total}, 700);
			animateValue("open_issues", 0, ${open}, 700);
			animateValue("closed_issues", 0, ${closed}, 700);

			document.querySelectorAll("tr.expandable").forEach(row => {
				row.addEventListener("click", () => {
					const repoId = row.getAttribute("data-repo");
					toggleExpandableContent(repoId);
				});
			});
		});
	</script>
	'
}

fn (i Issue) html_link() string {
	return '<a href="${i.url}" target="_blank" rel="noopener noreferrer" class="issue-link">${i.title}</a>'
}

fn (i Issue) to_li() string {
	return '<li>${i.html_link()}</li>'
}
