require 'rb-fsevent'
require 'rubygems/package'
require 'set'
require 'fileutils'
require 'zlib'
require 'pathname'
require 'tempfile'

# FileChangeObserver provides a method to invoke a block while capturing all
# filesystem changes made by that block under a particular subtree as a gzipped
# tarball.
module FileChangeObserver
  LATENCY = 0.01
  SENTINEL = ".__observe_files_break_now__".freeze
  ITEM_IS_DIR = 'ItemIsDir'.freeze
  SYS_SYNC = 36 # syscall number for sync(3) on darwin

  class << self
    # Watch a directory and generate a gzipped tarball of all the files
    # changed, modified, or otherwise touched while the given block is runs.
    #
    # See observe_changes for a handful of limitations regarding which changes
    # are included.
    def tar_changes(from_root, to: gen_tempfile_path, &block)
      affected_paths = observe_changes(from_root, &block)
      root_path = Pathname.new(File.realpath(from_root))

      Zlib::GzipWriter.open(to) do |gz_writer|
        Gem::Package::TarWriter.new(gz_writer) do |tar_writer|
          affected_paths.each do |file|
            add_file(tar_writer, file, root_path)
          end
        end
      end

      to
    end

    # Set up an fsevents handler on the given root directory, and, while
    # running the given block, collect a set of all the files changed under
    # that root.
    #
    # The tarball does not include any sort of deletion sentinel for files
    # deleted by the block, and does not include entries for directories (so
    # empty directories created by the block will not show up in the tarball).
    #
    # Additionally, a file doesn't have to be actually *changed* in order to be
    # returned; anything that generates an `fsevents` event is sufficient.
    def observe_changes(from_root)
      affected_paths = Set.new
      sentinel_path = File.join(from_root, SENTINEL)

      # if the directory was recently created, it *seems* like it needs to
      # actually be written out before we start the watch, otherwise we don't
      # receive any events.
      #
      # Unfortunately, sync(3) is a slow/expensive operation and a
      # newly-created direcotry is probably not the most common use-case. As a
      # compromise, we sync(3) only if the directory appears to have been
      # created in the past few seconds.
      if (Time.now - File.stat(from_root).ctime) < 5
        Kernel.syscall(SYS_SYNC)
      end

      fsevent = FSEvent.new
      fsevent.watch(from_root, file_events: true, latency: LATENCY) do |paths, meta|
        done = false
        meta['events'].each do |evt|
          # Don't track directories. We could change this...
          next if evt['flags'].include?(ITEM_IS_DIR)
          path = evt['path']
          # Because macOS delivers these events with a configurable latency, we
          # have to wait for it to flush its pipeline before we can escape from
          # the run loop, so we push this sentinel event after invoking the
          # block. We know we're done when we receive it.
          if path.end_with?(SENTINEL)
            done = true
          else
            affected_paths << path
          end
        end
        raise Interrupt if done
      end
      thr = Thread.new { fsevent.run }
      # If we yield before the handler is set up, early events will be
      # discarded.
      sleep 1e-6 until fsevent.instance_variable_get(:@running)

      yield

      # Once the thread recieves the event for the sentinel_path, it will
      # return, and #join will return.
      FileUtils.touch(sentinel_path)
      thr.join
      File.unlink(sentinel_path) # clean up

      affected_paths
    end

    private

    # Generate a path to a valid (non-existent) tempfile.
    def gen_tempfile_path
      tf = Tempfile.new('filechanges.tgz')
      tf_path = tf.path
      tf.close
      tf.unlink
      tf_path
    end

    # Add a file to the TarWriter. Since our events may correspond to
    # now-deleted files, we swallow ENOENT.
    def add_file(tar_writer, file, root_path)
      stat = File.stat(file)
      name = Pathname.new(file).relative_path_from(root_path).to_s
      tar_writer.add_file_simple(name, stat.mode, stat.size) do |io|
        File.open(file, 'rb') { |f| IO.copy_stream(f, io) }
      end
    rescue Errno::ENOENT
      nil
    end
  end
end

