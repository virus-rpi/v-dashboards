module main

import os
import time

fn write_html_file(path string, content string) ! {
	os.write_file(path, content)!
	println('Generated: ${path}')
}

fn render_page(title string, body string) string {
	timestamp := time.now()
	hours := time.offset() / 3600
	mins := (time.offset() % 3600) / 60
	exact_time_str := '${timestamp.custom_format('MMMM DD YYYY HH:mm')} UTC${if time.offset() >= 0 {
		'+'
	} else {
		'-'
	}}${hours:02}:${mins:02}'
	relative_time_str := timestamp.relative()
	return '
	<!DOCTYPE html>
	<html lang="en">
	<head>
		<meta charset="UTF-8">
		<title>${title}</title>
		<link rel="stylesheet" href="css/main.css">
		<script src="js/animated_value.js"></script>
	</head>
	<body>
		<h1>V Progress Dashboard</h1>
		<hr>
		${body}
		<hr>
		<footer>
			<small class="timestamp-wrapper">
				Data last updated
				<span class="timestamp-fade" style="width: max-content;">
					<span class="timestamp-rel">${relative_time_str}</span>
					<span class="timestamp-fixed">${exact_time_str}</span>
				</span>
			</small>
		</footer>
	</body>
	</html>
	'
}

fn generate_static() {
	os.mkdir_all('out') or {}
	os.mkdir_all('out/css') or {}
	os.mkdir_all('out/js') or {}

	// Copy static assets
	os.cp_all('static/css', 'out/css', true) or {}
	os.cp_all('static/js', 'out/js', true) or {}

	// Generate cards
	cards := get_cards()

	// Generate index.html
	mut cards_html := ''
	for card in cards {
		cards_html += card.to_html()
	}
	index_content := render_page('V Progress Dashboard', '<div class="card-container">${cards_html}</div>')
	write_html_file('out/index.html', index_content) or {}

	// Generate one page per card
	for card in cards {
		full_link := card.get_full_page_link().trim_left('/')
		if full_link == '' {
			continue
		}
		full_html := render_page(card.get_title(), '
			<br>
			<a href="index.html" class="button">Go back to home</a>
			<br><br><hr>
			${card.get_full_page_content()}
		')
		write_html_file('out/${full_link}.html', full_html) or {}
	}
}
