require 'json'
require 'faraday'
require 'fileutils'

# Notice: if you have the premium account, please setup ENV['LEETCODE_COOKIE'] and leetcode api will respond more info

@cookie = ENV['LEETCODE_COOKIE']
INCLUDE_QUESTION = true
INCLUDE_SOLUTION = true

OUTPUT_DIR = 'leetcode'
QUESTION_DATA_SUBDIR = 'problem_data'
SOLUTION_DATA_SUBDIR = 'solution_data'
PROBLEMS_FILE_NAME = 'problems'

STAT_KEY = 'stat'
FRONT_QUESTION_ID_KEY = 'frontend_question_id'
QUESTION_ID_KEY = 'question_id'
QUESTION_TITLE_SLUG_KEY = 'question__title_slug'

def fetch_problems
  url = 'https://leetcode.com/api/problems/algorithms/'
  @client.get(url).tap do |resp|
    raise "get_problems failed: #{resp.status}\n#{resp.body}" if resp.status != 200
  end
end

def post_graphql(body)
  body = body.to_json unless body.is_a? String
  url = 'https://leetcode.com/graphql'
  headers = {
      'Content-Type' => 'application/json',
      'cookie' => @cookie
  }
  @client.post(url, body, headers).tap do |resp|
    raise "graphql failed: #{resp.status}\n#{resp.body}" if resp.status != 200
  end
end

def fetch_question_data(title_slug)
  body = {
      operationName: 'questionData',
      variables: {titleSlug: title_slug},
      query: "query questionData($titleSlug: String!) {\n  question(titleSlug: $titleSlug) {\n    questionId\n    questionFrontendId\n    boundTopicId\n    title\n    titleSlug\n    content\n    translatedTitle\n    translatedContent\n    isPaidOnly\n    difficulty\n    likes\n    dislikes\n    isLiked\n    similarQuestions\n    contributors {\n      username\n      profileUrl\n      avatarUrl\n      __typename\n    }\n    langToValidPlayground\n    topicTags {\n      name\n      slug\n      translatedName\n      __typename\n    }\n    companyTagStats\n    codeSnippets {\n      lang\n      langSlug\n      code\n      __typename\n    }\n    stats\n    hints\n    solution {\n      id\n      canSeeDetail\n      __typename\n    }\n    status\n    sampleTestCase\n    metaData\n    judgerAvailable\n    judgeType\n    mysqlSchemas\n    enableRunCode\n    enableTestMode\n    envInfo\n    __typename\n  }\n}\n"
  }
  post_graphql(body)
end

def fetch_solution_data(title_slug)
  body = {
      operationName: 'QuestionNote',
      variables: {titleSlug: title_slug},
      query: "query QuestionNote($titleSlug: String!) {\n  question(titleSlug: $titleSlug) {\n    questionId\n    article\n    solution {\n      id\n      url\n      content\n      contentTypeId\n      canSeeDetail\n      rating {\n        id\n        count\n        average\n        userRating {\n          score\n          __typename\n        }\n        __typename\n      }\n      __typename\n    }\n    __typename\n  }\n}\n"
  }
  post_graphql(body)
end

def parse_problem_list(problems_body)
  problems_body = JSON.parse(problems_body) if problems_body.is_a? String
  problems_body['stat_status_pairs']
end

def create_dir_unless_exist(file_path)
  dir = File.dirname(file_path)
  FileUtils.mkpath(dir) unless File.exist?(dir)
end

def read_file(fname, root_dir: OUTPUT_DIR)
  File.read(File.join(root_dir, fname))
end

def save_to_file(text, fname, root_dir: OUTPUT_DIR)
  path = File.join(root_dir, fname)
  create_dir_unless_exist(path)
  File.write(path, text)
end

def save_problems_list_to_file(fname: PROBLEMS_FILE_NAME)
  save_to_file(fetch_problems.body, fname)
end

def get_title(metadata)
  metadata[STAT_KEY][QUESTION_TITLE_SLUG_KEY]
end

def build_question_file_name(metadata)
  title = get_title(metadata)
  front_id = metadata[STAT_KEY][FRONT_QUESTION_ID_KEY]
  id = metadata[STAT_KEY][QUESTION_ID_KEY]
  [front_id, id, title].join('.')
end

def save_single_question_to_file(metadata, include_question: INCLUDE_QUESTION, include_solution: INCLUDE_SOLUTION)
  title = get_title(metadata)
  if include_question
    question_fname = File.join(QUESTION_DATA_SUBDIR, build_question_file_name(metadata))
    save_to_file(fetch_question_data(title).body, question_fname)
  end
  if include_solution
    solution_fname = File.join(SOLUTION_DATA_SUBDIR, build_question_file_name(metadata) + '.solution')
    save_to_file(fetch_solution_data(title).body, solution_fname)
  end
end

def save_questions_to_file(front_id_included = 0..10000, front_id_excluded: [])
  list = parse_problem_list(fetch_problems.body)
  list.each do |problem|
    next if front_id_excluded.include? problem[STAT_KEY][FRONT_QUESTION_ID_KEY]
    next unless front_id_included.include? problem[STAT_KEY][FRONT_QUESTION_ID_KEY]
    save_single_question_to_file(problem)
  end
end




# main:
@client = Faraday.new
save_problems_list_to_file
save_questions_to_file
