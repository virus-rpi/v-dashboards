module main

import net.http
import os
import crypto.sha256
import time
import json

const cache_dir = 'cache'
const cache_expiration_seconds = 7 * 24 * 3600 // one week

struct SerializableResponse {
	body         string
	status_code  int
	status_msg   string
	http_version string
	created_at   i64
}

struct GitHubContent {
	name         string
	path         string
	content_type string @[json: 'type']
}

struct GitHubIssueSearchResult {
	total_count int
}

struct GitHubIssueSearchResponse {
	items []GitHubIssue
}

struct GitHubIssue {
	body     string
	title    string @[json: 'title']
	html_url string @[json: 'html_url']
}

fn get_authenticated_github(url string, token string) !http.Response {
	cache_file_name := url_to_cache_filename(url)

	mut cached := http.Response{}
	load_cache(cache_file_name, mut cached) or { http.Response{} }
	if cached != http.Response{} {
		return dump(cached)
	}

	mut req := http.new_request(http.Method.get, url, '')
	req.add_header(http.CommonHeader.authorization, 'token ' + token)
	mut resp := req.do()!

	remaining := resp.header.get_custom('X-RateLimit-Remaining') or { '0' }
	reset := resp.header.get_custom('X-RateLimit-Reset') or { '0' }

	if remaining == '0' {
		reset_unix := reset.int()
		now_unix := time.utc().unix()
		sleep_duration := reset_unix - now_unix
		if sleep_duration > 0 {
			println('Rate limit reached, sleeping for ${sleep_duration} seconds...')
			time.sleep(time.Duration(sleep_duration) * time.second)
		} else {
			println('Rate limit reached, but reset time is in the past, retrying in 1 sec...')
			time.sleep(1 * time.second)
		}
		mut req2 := http.new_request(http.Method.get, url, '')
		req2.add_header(http.CommonHeader.authorization, 'token ' + token)
		resp = req2.do()!
	}

	if resp.status_code == 200 {
		save_cache(cache_file_name, resp)!
	}

	return resp
}

fn url_to_cache_filename(url string) string {
	return os.join_path(cache_dir, sha256.sum256(url.bytes()).hex())
}

fn save_cache(filename string, resp http.Response) ! {
	os.mkdir_all(cache_dir)!
	sresp := serialize_response(resp)
	data := json.encode(sresp)
	os.write_file(filename, data)!
}

fn load_cache(filename string, mut cached http.Response) ! {
	if !os.exists(filename) {
		return error('cache file not found')
	}
	data := os.read_file(filename)!
	sresp := json.decode(SerializableResponse, data) or {
		return error('failed to decode cached response')
	}
	age := time.utc().unix() - sresp.created_at
	if age > cache_expiration_seconds {
		return error('cache expired')
	}
	cached = deserialize_response(sresp)
}

fn serialize_response(resp http.Response) SerializableResponse {
	return SerializableResponse{
		body:         resp.body
		status_code:  resp.status_code
		status_msg:   resp.status_msg
		http_version: resp.http_version
		created_at:   time.utc().unix()
	}
}

fn deserialize_response(sresp SerializableResponse) http.Response {
	return http.Response{
		body:         sresp.body
		status_code:  sresp.status_code
		status_msg:   sresp.status_msg
		http_version: sresp.http_version
	}
}
