require 'optparse'
require 'date'
require 'httpclient'

M4A_FILE = DateTime.now.strftime('%Y%m%d%H%M%S') + ".m4a"

LOGIN_URL = 'https://radiko.jp/ap/member/login/login'
LOGIN_CHECK_URL = 'https://radiko.jp/ap/member/webapi/member/login/check'
AUTH1_URL = 'https://radiko.jp/v2/api/auth1_fms'
AUTH2_URL = 'https://radiko.jp/v2/api/auth2_fms'

params = ARGV.getopts("", "sid:", "ft:", "to:", "mail:", "pass:")

if params["sid"] == nil || params["ft"] == nil || params["to"] == nil
    puts "Usage: ruby rec_radiko.rb --sid=<station id> --ft=<start time> --to=<end time> --mail=<mail address --pass=<password>"
    exit
end

sid = params["sid"]
ft = params["ft"]
to = params["to"]

PLAYLIST_URL = "https://radiko.jp/v2/api/ts/playlist.m3u8?station_id=#{sid}&l=15&ft=#{ft}&to=#{to}"

mail = params["mail"]
pass = params["pass"]

client = HTTPClient.new

header = { \
    'Content-Type' => 'application/x-www-form-urlencoded', \
    'Referer' =>  'http://radiko.jp/', \
    'Pragma' => 'no-cache', \
    'User-Agent' =>  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_4) AppleWebKit/603.1.30 (KHTML, like Gecko) Version/10.1 Safari/603.1.30', \
    'X-Radiko-Device' => 'pc', \
    'X-Radiko-App-Version' =>  '4.0.0', \
    'X-Radiko-User' =>  'test-stream', \
    'X-Radiko-App' => 'pc_ts' \
    }

# premium login
if mail != nil && pass != nil
    res = client.post(LOGIN_URL, {'mail' => mail, 'pass' => pass}, header)
    res = client.get(LOGIN_CHECK_URL, nil, header)
    if HTTP::Status.successful?(res.code) != true
        puts "Login failed"
        exit 1
    end
    puts "Login Succeed"
end

# Authentication 1
res = client.post(AUTH1_URL, nil, header)
if HTTP::Status.successful?(res.code) != true
    puts "Auth1 failed"
    exit 1
end
puts "Auth1 Succeed"

# X-Radiko-AuthToken が大文字の場合と小文字の場合があるため両方に対応
if res.headers['X-Radiko-AuthToken'] != nil
    header['X-Radiko-Authtoken'] = res.headers['X-Radiko-AuthToken']
elsif res.headers['X-RADIKO-AUTHTOKEN'] != nil
    header['X-Radiko-Authtoken'] = res.headers['X-RADIKO-AUTHTOKEN']
else
    puts "X-Radiko-AuthToken not found"
    exit 1
end
    
header['X-Radiko-Partialkey'] = `dd if=authkey.png ibs=1 skip=#{res.headers['X-Radiko-KeyOffset']} count=#{res.headers['X-Radiko-KeyLength']} 2>/dev/null | base64`.chomp

# Authentication 2
res = client.post(AUTH2_URL, nil, header)
if HTTP::Status.successful?(res.code) != true
    puts "Auth2 failed"
    exit 1
end
puts "Auth2 Succeed"

# ffmpegで保存
ffmpeg = "ffmpeg \
-content_type 'application/x-www-form-urlencoded' \
-headers 'Referer: http://radiko.jp/' \
-headers 'Pragma: no-cache' \
-headers 'X-Radiko-AuthToken: #{header['X-Radiko-Authtoken']}' \
-user_agent 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_4) AppleWebKit/603.1.30 (KHTML, like Gecko) Version/10.1 Safari/603.1.30' \
-i '#{PLAYLIST_URL}' \
-vn -acodec copy -bsf aac_adtstoasc #{M4A_FILE}"

`#{ffmpeg}`
