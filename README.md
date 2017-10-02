# FileChangeObserver

**This gem *only* supports macOS**.

```ruby
require 'tmpdir'

tgz_path = Dir.mktmpdir do |dir|
  FileChangeObserver.tar_changes(dir) do
    File.write("#{dir}/foo", 'neato')
    FileUtils.mkdir("#{dir}/bar")
    File.write("#{dir}/bar/baz", 'it works')
  end
end

# -rw-r--r--  0 wheel  wheel       5  2 Oct 15:01 foo
# -rw-r--r--  0 wheel  wheel       8  2 Oct 15:01 bar/baz
system("tar tvf #{tgz_path}")
File.unlink(tgz_path)
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'file_change_observer'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install file_change_observer
