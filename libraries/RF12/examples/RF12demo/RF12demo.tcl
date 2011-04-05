Jm doc "Driver for the RF12demo sketch."

proc AUTOSKETCH.START {device conn config} {
  # Called when this sketch has started, parse the config line to extract info.
  # device: name of device on which the sketch is running
  # conn: the connection object
  # config: config string from header line (may be empty)
  # Returns list for the command + args to call for incoming data lines.
  if {[regexp {^(\w) i(\d+)\*? g(\d+) @ (\d\d\d) MHz$} $config - a n g m]} {
    app devices set! $device net $m.$g node $n
    list [namespace which ParseMessage] $conn
  }
}

proc ParseMessage {conn msg} {
  # Called on each incoming line of text.
  # conn: the connection object
  # msg: the message text
  set device [$conn name]
  if {[string range $msg 0 2] eq " ? "} {
    #TODO move errors and valid stats fields out of the devices view
    app devices incr! $device errors
  } elseif {[regexp {^OK \d} $msg] && [string is list -strict $msg]} {
    app devices incr! $device valid
    lassign [app devices row $device sketch net] sketch net
    if {$sketch ne "" && $net ne ""} {
      set msg [lassign $msg - hdr]
      set type RF12:$net.[expr {$hdr % 32}]
      set bytes [binary format c* $msg]
      set handler [app nodes at $type sketch]
      set decoded [hub hook $handler RF12.DECODE $type $bytes]
      readings report $decoded
    }
  }
}

proc bitRemover {raw keep lose {skip 0}} {
  # Remove bits from a raw data packet in a repetitive pattern (parity, etc).
  # raw: the raw data bytes
  # keep: number of bits to keep
  # lose: number of bits to lose
  # skip: number of initial bits to ignore
  # Returns adjusted raw data.
  binary scan $raw b* bits
  set bits [string range $bits $skip end]
  set result ""
  while {$bits ne ""} {
    append result [string range $bits 0 $keep-1]
    set bits [string range $bits $keep+$lose end]
  }
  return [binary format b* $result]
}

proc bitSlicer {raw args} {
  # Take raw data bytes and slice them into integers on bit boundaries.
  # raw: the raw data bytes
  # args: list bits to extract for next int value (negative to sign-extend)
  # Returns the list of extracted integer values.
  binary scan $raw b* bits
  set result {}
  foreach x $args {
    set n [expr {abs($x)-1}]
    # extract bits, reverse them, then convert to an int
    set b [scan [string reverse [string range $bits 0 $n]] %b]
    if {$x < 0} {
      # sign-extend, major bit-trickery!
      set m [expr {1 << $n}]
      set b [expr {($b ^ $m) - $m}]
    }
    lappend result $b
    set bits [string range $bits $n+1 end]
  }
  return $result
}

Jm rev {$Id: RF12demo.tcl 7406 2011-03-27 16:16:02Z jcw $}
