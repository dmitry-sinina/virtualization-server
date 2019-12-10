# this program demonstrates the use of the libvirt event APIs.  This example
# is very, very complicated because:
# 1) the libvirt event APIs are complicated and
# 2) it tries to simulate a multi-threaded UI program, leading to some weirdness

require 'libvirt'
require 'epoll'
require_relative '../logger_mutex'

module Virt
  class Loop
    class Handle
      # represents an event handle (usually a file descriptor).  When an event
      # happens to the handle, we dispatch the event to libvirt via
      # Libvirt::event_invoke_handle_callback (feeding it the handle_id we returned
      # from add_handle, the file descriptor, the new events, and the opaque
      # data that libvirt gave us earlier)
      attr_accessor :handle_id, :fd, :io, :events
      attr_reader :opaque

      def initialize(handle_id, fd, events, opaque)
        #~ puts "Virt::Loop::Handle.initialize"
        @handle_id = handle_id
        @io = IO.new(fd, mode: 'r+', autoclose: false)
        @fd = fd
        @events = events
        @opaque = opaque
      end

      def dispatch(events)
        #~ puts "Virt::Loop::Handle#dispatch events #{events}"
        Libvirt::event_invoke_handle_callback(@handle_id, @fd, events, @opaque)
      end
    end

    class Timer
      # represents a timer.  When a timer expires, we dispatch the event to
      # libvirt via Libvirt::event_invoke_timeout_callback (feeding it the timer_id
      # we returned from add_timer and the opaque data that libvirt gave us
      # earlier)
      attr_accessor :lastfired, :interval
      attr_reader :timer_id, :opaque

      def initialize(timer_id, interval, opaque)
        #~ puts "Virt::Loop::Timer.initialize #{timer_id} #{interval}"
        @timer_id = timer_id
        @interval = interval
        @opaque = opaque
        @lastfired = 0
      end

      def dispatch
        #~ puts "Virt::Loop::Timer#dispatch #{@timer_id}"
        Libvirt::event_invoke_timeout_callback(@timer_id, @opaque) if @interval > 0
      end
    end

    class EventsIdPair
      attr_reader :libvirt_id, :epoll_id
      def initialize(libvirt_id, epoll_id)
        @libvirt_id = libvirt_id
        @epoll_id = epoll_id
      end
    end

    def initialize
      dbg 'initialize'

      @handles = []
      @next_handle_id = 1

      @timers = []
      @next_timer_id = 1

      @mutex = LoggerMutex.new(self.class.name)
      @epoll = Epoll.create

      # a bit of oddness having to do with signalling.  Since signals are
      # unreliable in a multi-threaded program, create a "self-pipe".  The read
      # end of the pipe will be part of the pollin array, and will be selected
      # on during "run_once".  The write end of the pipe is available to the
      # callbacks registered with libvirt.  When libvirt does an add, update,
      # or remove of either a handle or a timer, the callbacks will write a single
      # byte (via the interrupt method) to the write end of the pipe.  This will
      # cause the select loop in "run_once" to wakeup and recalculate the
      # polling arrays and timers based on the new information.
      @rdpipe, @wrpipe = IO.pipe
      @pending_wakeup = false
      @running_poll = false
      @quit = false

      @timers = []

      dbg "register rdpipe with fd #{@rdpipe.fileno} in epoll"
      @epoll.add(@rdpipe, Epoll::IN | Epoll::ERR | Epoll::HUP)

      @libvirt_events_to_epoll_map = []
      [
        [Libvirt::EVENT_HANDLE_READABLE, Epoll::IN],
        [Libvirt::EVENT_HANDLE_WRITABLE, Epoll::OUT],
        [Libvirt::EVENT_HANDLE_ERROR, Epoll::ERR],
        [Libvirt::EVENT_HANDLE_HANGUP, Epoll::HUP],
      ].each { |m| @libvirt_events_to_epoll_map << EventsIdPair.new(*m) }
      p @libvirt_events_to_epoll_map

      register_handlers
    end

    def run_loop
      dbg 'run_loop'
      #~ Thread.current.name = "Virt::Loop"
      #~ Thread.current.abort_on_exception = true
      # run "run_once" forever
      while true
        run_once
      end
    end

    private

    def next_timeout()
      # calculate the smallest timeout of all of the registered timeouts
      nexttimer = 0
      @mutex.synchronize {
          @timers.each do |t|
            dbg "timer #{t.timer_id} last #{t.lastfired} interval #{t.interval}"
            next if t.interval < 0
            if nexttimer == 0 || (t.lastfired + t.interval) < nexttimer
              nexttimer = t.lastfired + t.interval
            end
          end
      }
      nexttimer
    end

    def run_once
      # the main loop of the program.  This loop first calculates the smallest
      # timeout value (via next_timeout).  Based on that, it knows how long to
      # sleep for in the select (it sleeps forever if there are no timers
      # registered).  It then does a select on all of the registered file
      # descriptors, waking up if one of them becomes active or we hit the
      # timeout.  If one of the file descriptors becomes active, we properly
      # dispatch the handle event to libvirt.  If we woke up because of a timeout
      # we dispatch the timeout callback to libvirt.
      dbg 'run_once'

      @running_poll = true

      nexttimer = next_timeout()
      dbg "Next timeout at #{nexttimer}"
  
      sleep = -1
      if nexttimer > 0
        now = Time.now.to_i * 1000
        if now >= nexttimer
          sleep = -1
        else
          sleep = (nexttimer - now)
        end
      end

      events = @epoll.wait(sleep)

      dbg "@epoll.wait(#{sleep}) ok"
      #~ p events

      @mutex.synchronize {

        events.each do |ev|
            dbg "ev.events #{ev.events} ev.data: #{ev.data} fd: ev.data.fileno: #{ev.data.fileno}"
            if ev.data == @rdpipe
              @mutex.synchronize {
                @pending_wakeup = false
                @rdpipe.read(1)
              }
              next
            end

            handle = @handles.detect { |h| h.io == ev.data }
            if handle.nil?
              dbg "ERROR: failed to find appropriate handle for triggered IO #{ev.data}"
              next
            end
            dbg "dispatch handle: #{handle}"
            handle.dispatch(epoll_events_to_libvirt(ev.events))
        end #events.each do |ev|

        dbg 'process timers'
        now = Time.now.to_i * 1000
        @timers.each do |t|
          next if t.interval < 0
          want = t.lastfired + t.interval
          if now >= (want - 20)
            t.lastfired = now
            dbg "dispatch timer: #{t} #{t.timer_id}"
            t.dispatch
          end
        end #@timers.each do |t|

      } #@mutex.synchronize

      @running_poll = false
    end

    def interrupt
      # write a byte to the internal pipe to wake up "run_once" for recalculation.
      # See initialize for more information about the internal pipe
      dbg '> interrupt'
      if @running_poll && !@pending_wakeup
        @pending_wakeup = true
        @wrpipe.write('c')
      end
    end

    def libvirt_events_to_epoll(events)
      ret = 0
      @libvirt_events_to_epoll_map.each do |i|
        ret |= i.epoll_id if (events & i.libvirt_id) != 0
      end
      dbg "#{events} -> #{ret}"
      ret
    end
    
    
    def epoll_events_to_libvirt(events)
      ret = 0
      @libvirt_events_to_epoll_map.each do |i|
        ret |= i.libvirt_id if (events & i.epoll_id) != 0
      end
      dbg "#{events} -> #{ret}"
      ret
    end

    def add_io(io, events)
      dbg "#{io.fileno} #{events}"
      @epoll.add(io, libvirt_events_to_epoll(events))
    end

    def mod_io(io, events)
      dbg "#{io.fileno} events #{events}"
      if events != 0
        begin
            @epoll.mod(io, libvirt_events_to_epoll(events))
        rescue
            #for cases when io was removed from epoll because of zero events
            @epoll.add(io, libvirt_events_to_epoll(events))
        end
      else
        @epoll.del(io)
      end
    end

    def del_io(io)
      dbg "io:#{io.fileno}"
      @epoll.del(io)
    end

    def add_handle(fd, events, opaque)
      # add a handle to be tracked by this object.  The application is
      # expected to maintain a list of internal handle IDs (integers); this
      # callback *must* return the current handle_id.  This handle_id is used
      # both by libvirt to identify the handle (during an update or remove
      # callback), and is also passed by the application into libvirt when
      # dispatching an event.  The application *must* also store the opaque
      # data given by libvirt, and return it back to libvirt later
      # (see remove_handle)
      dbg "> fd:#{fd}"
      handle_id = nil
      @mutex.synchronize {
        handle_id = @next_handle_id + 1
        @next_handle_id = handle_id
        handle = Virt::Loop::Handle.new(handle_id, fd, events, opaque)
        @handles << handle
        add_io(handle.io, handle.events)
        interrupt
      }
      handle_id
    end

    def update_handle(handle_id, events)
      # update a previously registered handle.  Libvirt tells us the handle_id
      # (which was returned to libvirt via add_handle), and the new events.  It
      # is our responsibility to find the correct handle and update the events
      # it cares about
      dbg "> handle_id:#{handle_id}, events:#{events}"
      #~ p *caller
      @mutex.synchronize {
        handle = @handles.detect { |h| h.handle_id == handle_id }
        dbg "handle_id #{handle_id} with fd #{handle.fd} #{handle.events}-> #{events}"
        handle.events = events
        mod_io(handle.io, handle.events)
      }
      nil
    end

    def remove_handle(handle_id)
      # remove a previously registered handle.  Libvirt tells us the handle_id
      # (which was returned to libvirt via add_handle), and it is our
      # responsibility to "forget" the handle.  We must return the opaque data
      # that libvirt handed us in "add_handle", otherwise we will leak memory
      dbg "> handle_id:#{handle_id}"
      opaque = nil
      @mutex.synchronize {
        idx = @handles.index { |h| h.handle_id == handle_id }
        unless idx.nil?
          handle = @handles.delete_at(idx)
          dbg "handle_id #{handle_id} idx #{idx} fd #{handle.fd}"
          opaque = handle.opaque
          del_io(handle.io)
        end
      }
      opaque
    end

    def add_timer(interval, opaque)
      # add a timeout to be tracked by this object.  The application is
      # expected to maintain a list of internal timer IDs (integers); this
      # callback *must* return the current timer_id.  This timer_id is used
      # both by libvirt to identify the timeout (during an update or remove
      # callback), and is also passed by the application into libvirt when
      # dispatching an event.  The application *must* also store the opaque
      # data given by libvirt, and return it back to libvirt later
      # (see remove_timer)
      dbg "> interval #{interval}"
      timer_id = nil
      @mutex.synchronize {
        timer_id = @next_timer_id + 1
        @next_timer_id = timer_id
        @timers << Virt::Loop::Timer.new(timer_id, interval, opaque)
        interrupt
      }
      timer_id
    end

    def update_timer(timer_id, interval)
      # update a previously registered timer.  Libvirt tells us the timer_id
      # (which was returned to libvirt via add_timer), and the new interval.  It
      # is our responsibility to find the correct timer and update the timers
      # it cares about
      dbg "> timer_id:#{timer_id}"
      #~ p *caller

      @mutex.synchronize {
        timer = @timers.detect { |t| t.timer_id == timer_id }
        if timer and timer.interval!=interval
          dbg "updating timer #{timer.timer_id} #{timer.interval} -> #{interval}"
          timer.interval = interval
          interrupt
        end
      }
      nil
    end

    def remove_timer(timer_id)
      # remove a previously registered timeout.  Libvirt tells us the timer_id
      # (which was returned to libvirt via add_timer), and it is our
      # responsibility to "forget" the timer.  We must return the opaque data
      # that libvirt handed us in "add_timer", otherwise we will leak memory
      dbg "> timer_id:#{timer_id}"
      opaque = nil
      @mutex.synchronize {
        idx = @timers.index { |t| t.timer_id == timer_id }
        unless idx.nil?
          dbg "Remove timer #{timer.timer_id}"
          timer = @timers.delete_at(idx)
          opaque = timer.opaque
          interrupt
        end
      }
      opaque
    end

    def register_handlers
      dbg 'register_handlers'
      Libvirt::event_register_impl(
          method(:add_handle).to_proc,
          method(:update_handle).to_proc,
          method(:remove_handle).to_proc,
          method(:add_timer).to_proc,
          method(:update_timer).to_proc,
          method(:remove_timer).to_proc
      )
    end

    private

    def dbg(msg)
      meth_name = caller.first.match(/`(.+)'/)[1]
      AppLogger.debug("0x#{object_id.to_s(16)}") { "#{self.class}::#{meth_name} #{msg}" }
    end
  end
end
