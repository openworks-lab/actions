#!/usr/bin/env ruby
require 'json'
require 'open3'
require 'tmpdir'
require 'yaml'

workflow = YAML.load_file(File.expand_path('../.github/workflows/static-publish-to-s3.yml', __dir__))
step = workflow.fetch('jobs').fetch('publish').fetch('steps').find { |s| s['id'] == 'sync' }
policy = 'no-cache, max-age=0, must-revalidate'

def assert(condition, message)
  raise message unless condition
  puts "통과: #{message}"
end

def run_sync(script, enabled, failure_at = 0)
  Dir.mktmpdir('static-publish-test-') do |dir|
    aws = File.join(dir, 'aws')
    File.write(aws, <<~RUBY)
      #!/usr/bin/env ruby
      require 'json'
      path = ENV.fetch('AWS_CALLS')
      File.open(path, 'a') { |f| f.puts(JSON.generate(ARGV)) }
      exit 27 if File.readlines(path).length == ENV.fetch('FAILURE_AT').to_i
    RUBY
    File.chmod(0o755, aws)
    calls_path = File.join(dir, 'calls.jsonl')
    output_path = File.join(dir, 'output')
    stdout, stderr, status = Open3.capture3({
      'PATH' => "#{dir}:#{ENV.fetch('PATH')}", 'AWS_CALLS' => calls_path,
      'FAILURE_AT' => failure_at.to_s, 'GITHUB_OUTPUT' => output_path,
      'BUCKET' => 'openworks-dev-open-echo-site', 'PREFIX' => 'nested path/',
      'OUTDIR' => 'build output', 'REVALIDATE_HTML' => enabled.to_s
    }, 'bash', '-c', script)
    calls = File.exist?(calls_path) ? File.readlines(calls_path).map { |line| JSON.parse(line) } : []
    output = File.exist?(output_path) ? File.read(output_path) : ''
    [calls, output, status, stdout + stderr]
  end
end

source = 'build output/'
dest = 's3://openworks-dev-open-echo-site/nested path/'
calls, output, status, = run_sync(step.fetch('run'), false)
assert(status.success?, '기본 경로가 성공한다')
assert(calls == [['s3', 'sync', source, dest, '--delete']], '기본 sync 인수를 보존한다')
assert(output == "s3-uri=#{dest}\n", 'prefix와 공백 경로 및 출력 계약을 보존한다')

calls, output, status, = run_sync(step.fetch('run'), true)
assert(status.success?, 'HTML 선택 적용이 성공한다')
assert(calls == [
  ['s3', 'sync', source, dest, '--delete', '--exclude', '*.html'],
  ['s3', 'sync', source, dest, '--delete', '--exclude', '*', '--include', '*.html', '--cache-control', policy],
  ['s3', 'cp', source, dest, '--recursive', '--exclude', '*', '--include', '*.html', '--cache-control', policy]
], '일반 파일 뒤 HTML을 동기화하고 동일 내용 HTML에도 메타데이터를 다시 적용한다')
assert(output == "s3-uri=#{dest}\n", '선택 적용도 출력 계약을 보존한다')

calls, output, status, = run_sync(step.fetch('run'), true, 2)
assert(status.exitstatus == 27 && calls.length == 2 && output.empty?, '업로드 실패 후 성공 출력과 후속 업로드를 막는다')

trigger = workflow.fetch('on', workflow[true])
option = trigger.fetch('workflow_call').fetch('inputs').fetch('revalidate-html')
assert(option['type'] == 'boolean' && option['default'] == false, '공용 옵션은 boolean이고 기본 비활성이다')
assert(step.fetch('env')['REVALIDATE_HTML'] == '${{ inputs.revalidate-html }}', '선택값을 실제 업로드 단계에 전달한다')
assert(step['if'] == '${{ inputs.publish }}', 'publish=false일 때 AWS 업로드를 실행하지 않는다')
