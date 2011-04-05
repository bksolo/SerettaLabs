Jm doc "Decoder for the radioBlip sketch."

proc RF12.DECODE {name raw} {
  set count [RF12demo bitSlicer $raw 32]
  Ju tag $name blip $count days [expr {$count/(86400/64)}] report {
    # Value ping "counter" {$blip} counts
    Value age "age" {$days} days
  }
}

Jm rev {$Id: radioBlip.tcl 7372 2011-03-18 10:09:52Z jcw $}
