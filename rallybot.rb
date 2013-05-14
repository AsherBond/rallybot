$LOAD_PATH.unshift(*Dir[File.dirname(__FILE__) + "/vendor/gems/**/lib"])
require 'yaml'
require 'cinch'
require 'rally_api'
require 'html2md'


def lookup_iteration(number, scope_up=false, scope_down=true)
  iter_query = RallyAPI::RallyQuery.new()
  iter_query.type = "iteration"
  iter_query.project_scope_up = scope_up
  iter_query.project_scope_down = scope_down
  iter_query.query_string = "(Name = \"Iteration #{number.to_s}\")"
  results = $rally.find(iter_query)
  return results[0]
end


def show_board(show_stories=true)
  iteration = lookup_iteration($iteration)
  query = RallyAPI::RallyQuery.new()
  query.type = "story"
  query.fetch = "FormattedID,Name"
  query.project_scope_up = false
  query.project_scope_down = true
  query.query_string = "(Iteration = \"%s\")" % iteration.ref
  query.order = "FormattedID Asc"
  results = $rally.find(query)
  output = ""
  results.each do |story|
    story.read
    output += "#{story.FormattedID}: #{story.Name}\r" if show_stories
    story.Tasks.each do |task|
      task.read
      output += "   #{task.FormattedID}: #{task.Name} (#{task.Owner ? task.Owner : "UNASSIGNED"}) (#{task.State})\r"
    end
  end
  return output
end


def show_object(obj_type, obj_id)
  output = Array.new
  begin
    req_obj = $rally.read(obj_type.to_sym, "FormattedID|#{obj_id.upcase}")
    banner = "#" * 60

    output.push(banner)
    output.push([req_obj.FormattedID, req_obj.Name].join(": "))
    output.push(["Description", Html2Md.new(req_obj.Description).parse].join(": "))
    output.push(["Blocked", req_obj.Blocked].join(": "))

    if req_obj.type == "task"
      output.push(["Owner", req_obj.Owner].join(": "))
    end

    case req_obj.type.to_s
    when "task"
      output.push(["State", req_obj.State].join(": "))
      tmp = $rally.read(:story, req_obj.WorkProduct.ref)
      output.push(["Parent Story", "#{tmp.FormattedID} - #{tmp.Name}"].join(": "))
      output.push(["Points", req_obj.Estimate.to_i].join(": "))
    when "hierarchicalrequirement"
      output.push(["State", req_obj.ScheduleState].join(": "))
      tasks = Array.new
      req_obj.Tasks.each do |task|
	task.read
	tasks.push(task.FormattedID)
      end
      output.push(["Tasks", tasks.join(", ")].join(": "))
      output.push(["Remaining Points", req_obj.TaskRemainingTotal.to_i].join(": "))
    when "defect"
      output.push(["State", req_obj.State].join(": "))
    end

    output.push(["Notes", Html2Md.new(req_obj.Notes).parse].join(": "))
    output.push(banner)
  rescue
    output.push("Oh Noes!! I am unable to communicate with Rally")
  end

  return output.join("\r")
end


def update_obj(rally_obj, rally_id, comment)
    tmp_obj = $rally.read(rally_obj.to_sym, "FormattedID|#{rally_id.upcase}")
    previous = tmp_obj.Notes
    fields = {}
    fields["Notes"] = previous + "<br>" + comment
    tmp_obj.update(fields)
end


def create_obj(rally_object_type, subject, parent_id=nil)
  iteration = lookup_iteration($iteration)
  fields = Hash.new
  fields["Name"] = subject
  fields["Iteration"] = iteration.ref
  if not parent_id.nil?
    parent = $rally.read(:story, "FormattedID|#{parent_id}")
    fields["WorkProduct"] = parent.ref
  end
  new_object = $rally.create(rally_object_type.to_sym, fields)
  return new_object.FormattedID
end

##### MAIN #####

bot = Cinch::Bot.new do
  config = YAML.load_file('rallybot_config.yml')
  configure do |c|
    c.server = config["server"]
    c.nick = config["nick"]
    c.channels = config["channels"]
    c.messages_per_second = 1
    c.server_queue_size = 1
    rally_config = {
      :username => config["username"],
      :password => config["password"],
      :workspace => config["workspace"],
      :project => config["project"]
    }
    $rally = RallyAPI::RallyRestJson.new(rally_config)
    $iteration = 4
  end

  on :message, /^rallybot: show board/ do |m|
    m.reply "#{m.user.nick}: showing board in a private msg"
    msg = show_board()
    # reply directly to user
    User(m.user.nick).send msg
  end

  on :message, /^rallybot: show (story|task|defect) ([a-zA-Z]{2}[0-9]{1,5})$/ do |m, obj, id|
    m.reply "#{m.user.nick}: showing #{id} in a private msg"
    msg = show_object(obj, id)
    User(m.user.nick).send msg
  end

  on :message, /^rallybot: update (story|task|defect) ([a-zA-Z]{2}[0-9]{1,5}) (.*)$/ do |m, obj, id, comment|
    update_obj(obj, id, comment)
    m.reply "#{m.user.nick}: Updated notes for #{id}"
  end

  on :message, /^rallybot: create (story|defect) (.*)/ do |m, obj, subject|
    obj_id = create_obj(obj, subject)
    m.reply "#{m.user.nick}: Created #{obj_id}"
  end

  on :message, /^rallybot: create (task) ([a-zA-Z]{2}[0-9]{1,5}) (.*)/ do |m, obj, parent_id, subject|
    obj_id = create_obj(obj, subject, parent_id)
    m.reply "#{m.user.nick}: Created #{obj_id}"
  end

  trap "SIGINT" do
    bot.quit
  end
end

bot.start
