#!/usr/bin/env ruby

# Bot Blocking Statistics
# Usage: rails runner bin/bot_blocking_stats.rb

puts "🤖 Bot Blocking Statistics - #{Time.current.strftime('%Y-%m-%d %H:%M')}"
puts "=" * 60

# Get blocked bot logs from the last 24 hours
recent_blocked = Log.where('occurred_at > ?', 24.hours.ago)
                    .where("message ILIKE ?", "%[BOT_BLOCKED]%")
                    .order(occurred_at: :desc)

if recent_blocked.any?
  puts "📊 Blocked Requests (Last 24 hours): #{recent_blocked.count}"
  
  # Group by reason
  by_reason = recent_blocked.group_by do |log|
    log.message.match(/\[BOT_BLOCKED\] (\w+):/)[1] rescue 'unknown'
  end
  
  puts "\n📈 Breakdown by Block Reason:"
  by_reason.each do |reason, logs|
    puts "   #{reason}: #{logs.count}"
  end
  
  # Most common paths
  paths = recent_blocked.map do |log|
    match = log.message.match(/(?:GET|POST|PUT|DELETE|PATCH) ([^\s]+)/)
    match[1] if match
  end.compact
  
  if paths.any?
    puts "\n🎯 Most Targeted Paths:"
    path_counts = paths.tally.sort_by { |_, count| -count }.take(10)
    path_counts.each do |path, count|
      puts "   #{path}: #{count} attempts"
    end
  end
  
  # Most common user agents
  user_agents = recent_blocked.map do |log|
    match = log.message.match(/ - (.+)$/)
    if match
      ua = match[1].strip
      # Truncate long user agents
      ua.length > 50 ? ua[0..47] + "..." : ua
    end
  end.compact
  
  if user_agents.any?
    puts "\n🕵️ Most Common Bot User Agents:"
    ua_counts = user_agents.tally.sort_by { |_, count| -count }.take(10)
    ua_counts.each do |ua, count|
      puts "   #{ua}: #{count} requests"
    end
  end
  
  # Recent samples (last 5)
  puts "\n🔍 Recent Blocked Attempts:"
  recent_blocked.limit(5).each do |log|
    time = log.occurred_at.strftime("%H:%M:%S")
    puts "   [#{time}] #{log.message.gsub('[BOT_BLOCKED] ', '')}"
  end

else
  puts "✅ No bot requests blocked in the last 24 hours"
end

# Check overall request volume for comparison
total_requests = Log.where('occurred_at > ?', 24.hours.ago)
                    .where(log_type: 'http_request')
                    .count

if total_requests > 0
  blocked_percentage = (recent_blocked.count.to_f / (total_requests + recent_blocked.count) * 100).round(2)
  puts "\n📋 Summary:"
  puts "   Total legitimate requests: #{total_requests}"
  puts "   Blocked bot requests: #{recent_blocked.count}"
  puts "   Blocked percentage: #{blocked_percentage}%"
end

puts "\n" + "=" * 60
puts "🛡️  Bot protection stats completed"