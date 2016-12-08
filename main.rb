require 'rufus-scheduler'
require 'net/http'
require 'json'
require 'yaml'
require 'easy_diff'
require 'pp'
require 'cinch'

def unload_previous
	File.open('previous.yaml','w') do |h|
	   h.write $previous.to_yaml
	end
end

def load_previous
	if File.exists? "previous.yaml"
		$previous = YAML.load_file('previous.yaml')
	else
		$previous = {}
	end
end

def load_settings
	if File.exists? "settings.yaml"
		$settings = YAML.load_file('settings.yaml')
	else
		raise "No 'settings.yaml' file"
	end
end

def map_members(members)
	members.inject(Hash.new) { |h, object| h[object["id"]] = object; h  }
end

def fetch_leaderboard(leaderboard_id, session_id)
	path = "/2016/leaderboard/private/view/#{leaderboard_id}.json"
	http = Net::HTTP.new("adventofcode.com", 80)
	headers = {
		'Cookie' => "session=#{session_id}"
	}
	resp = http.get(path, headers)
	JSON.parse(resp.body)
end

def compute_diff(prev, res)
	removed, added = prev.easy_diff res
	added
end

def pretty_print_challenges_diff(prev, diff)
	diff.map do |id, changes|
		name = if prev.has_key?(id)
			prev[id]["name"]
		else
			changes["name"]
		end
		challenges_completed = changes["completion_day_level"]
		next if challenges_completed.nil?

		challenges_completed.map do |day|
			day, chs = day
			chs = chs.keys.sort.join ' and '
			"#{name} finished challenge #{chs} day #{day}!!"
		end.flatten
	end.flatten
end

def do_fetch
	res = fetch_leaderboard($settings['leaderboard_id'], $settings['session_cookie'])
	new = map_members res['members'].values
	diff = compute_diff $previous, new
	messages = pretty_print_challenges_diff $previous, diff
	$previous = new
	messages.each do |m|
		$bot.channels.each { |c| c.send m }
	end
	unload_previous
end

load_settings

$bot = Cinch::Bot.new do
	configure do |c|
		c.server = $settings['irc_server']
		c.channels = [$settings['irc_channel']]
		c.nick = $settings['irc_nick']
		c.port = $settings['irc_port']
		c.user = $settings['irc_user']
		c.ssl.use = true
	end

	on :connect do
		do_fetch
		scheduler = Rufus::Scheduler.new
		scheduler.every '1h' do
			do_fetch
		end
	end
end

load_previous

$bot.start


