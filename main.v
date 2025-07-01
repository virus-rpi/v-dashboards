module main

import veb
import os

pub struct Context {
	veb.Context
}

pub struct App {
	veb.StaticHandler
	cards []CardInterface
}

interface CardInterface {
	get_title() string
	get_content() string
	get_full_page_link() string
	get_full_page_content() string
}

struct Card {
	title          string
	full_page_link string
}

fn (card Card) get_title() string {
	return card.title
}

fn (card Card) get_content() string {
	return 'This is a card with title: ' + card.title
}

fn (card Card) get_full_page_link() string {
	return card.full_page_link
}

fn (card Card) get_full_page_content() string {
	return 'This is the full page content for card: ' + card.title
}

fn (card CardInterface) to_html() string {
	mut res := '
	<div class="card">
		<h2>${card.get_title()}</h2>
		<p>${card.get_content()}</p>'
	if card.get_full_page_link() != '' {
		res += '<br><a href="${card.get_full_page_link()}" class="button">More</a>'
	}
	res += '
	</div>'
	return res
}

pub fn (app &App) index(mut ctx Context) veb.Result {
	cards := app.cards
	mut cards_html := ''
	for card in cards {
		cards_html += card.to_html()
	}

	return ctx.html('
		<head>
  		  <link rel="stylesheet" type="text/css" href="/css/main.css">
  		  <script src="/js/animated_value.js"></script>
  		</head>
  		<body>
  		  <h1>V Progress Dashboard</h1>
  		  <hr>
  		  <div class="card-container">
  		  	${cards_html}
  		  </div>
  		</body>
	')
}

@['/:path']
pub fn (app &App) full_page(mut ctx Context, path string) veb.Result {
	cards := get_cards()
	for card in cards {
		if card.get_full_page_link().trim_left('/') == path {
			return ctx.html('
				<head>
  		  			<link rel="stylesheet" type="text/css" href="/css/main.css">
  		  			<script src="/js/animated_value.js"></script>
  				</head>
  				<body>
  		  			<h1>${card.get_title()}</h1>
  		  			<hr>
  		  			<br>
  		  			<a href="/" class="button">Go back to home</a>
  		  			<br>
  		  			<br>
  		  			<hr>
  		  			<p>${card.get_full_page_content()}</p>
  				</body>
			')
		}
	}
	return ctx.not_found()
}

pub fn (mut ctx Context) not_found() veb.Result {
	ctx.res.set_status(.not_found)
	return ctx.html('
		<head>
  		  <link rel="stylesheet" type="text/css" href="/css/main.css">
  		  <script src="/js/animated_value.js"></script>
  		</head>
  		<body>
  		  <h1>V Progress Dashboard</h1>
  		  <hr>
  		  <h2>Page not found!</h2>
  		  <br>
  		  <a href="/" class="button">Go back to home</a>
  		</body>
	')
}

fn get_cards() []CardInterface {
	return [
		VLibDocs.new(),
		Go2V.new(),
		UIRoadmap.new(),
	]
}

fn load_env(file string) ! {
	content := os.read_file(file)!
	lines := content.split('\n')
	for line in lines {
		if line.trim_space().len == 0 || line.starts_with('#') {
			continue
		}
		parts := line.split('=')
		if parts.len == 2 {
			key := parts[0].trim_space()
			value := parts[1].trim_space()
			os.setenv(key, value, true)
		}
	}
}

fn main() {
	token := os.getenv('GITHUB_TOKEN')
	if token == '' {
		load_env('.env')!
	}

	if '--static' in os.args {
		generate_static()
		return
	}
	mut app := &App{
		cards: get_cards()
	}
	app.handle_static('static', true)!
	veb.run[App, Context](mut app, 8080)
}
