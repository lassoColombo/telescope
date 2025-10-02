def enumerate-table-paths [t] {

  def enumerate-record-paths [record] {
    def recurse [prefix: list<string>, value: any] {
      if ($value | describe | str starts-with "record") {
        $value
        | columns
        | each {|k|
          let newpath = if ($prefix | is-empty) { [$k] } else { $prefix | append $k }
          [$newpath] ++ (recurse $newpath ($value | get $k))
        }
        | flatten
      } else {
        []
      }
    }

    recurse [] $record
  }

  $t | reduce --fold [] {|record acc|
    $acc | append (enumerate-record-paths $record)
  }
  | uniq
}

def finders [] {
  {
    record: {|current: any previous: any, _: closure|

      let preview = {
        let path = $in
        if $path == __return-this__ {
          $current
        } else if $path == __prev-item__ {
          $previous
        } else {
          $current | get $path
        } 
        | table -e -d 1
      }

      [__return-this__ __prev-item__] 
      | append ($current | columns) 
      | sk --preview-window right:80% --prompt 'record - choose a field: '  --preview $preview

    }
    list: {|current: any previous: any, IDclosure: closure|

      let col = $current | do $IDclosure
      if ($col | is-empty) { print $"(ansi yellow)aborted(ansi reset)"; return }
      let allvals = $current | get ($col | into cell-path)

      let preview = {
        let val = $in
        if $val == __return-this__ {
          $current
        } else if $val == __prev-item__ {
          $previous
        } else {
          $current | where {($in | get ($col | into cell-path)) == $val.item} | first
        }
        | table -e -d 1
      }

      let format = {
        let val = $in
        if $val == __prev-item__ or $val == __return-this__ {
          return $val
        }
        $val.item
      }

      let value = [__return-this__ __prev-item__] 
      | append ($allvals | enumerate) 
      | sk --preview-window right:80% --prompt 'list - choose an object:' --preview $preview --format $format

      if ($value == __return-this__ or $value == __prev-item__) {
        return $value
      }

      return $value.index
    }
  }
}

export def main [
  --IDstring: string
  --IDclosure: closure
] {
  let res = $in
  mut objs = [$res]
  mut columns: any = null
  while true {
    let len = $objs | length
    let previous = if ($len == 0) {
      return # the user chose 'previous' until the end and exited
    } else if ($len == 1) {
      null # there is only one element, no previous
    } else {
      $objs | get ($len - 2) 
    }
    let current = $objs | last

    let t = $current | describe
    let type = if ($t | str starts-with record) {
      $columns = $current | columns
      'record'
    } else if ($t | str starts-with list) or ($t | str starts-with table) {
      $columns = 0..(($current | length) - 1)
      'list'
    } else {
      return $current
    }

    let IDclosure = if ($IDclosure | is-not-empty) {
      $IDclosure
    } else if ($IDstring | is-not-empty) {
      {$IDstring| split row .}
    } else {
      {
        enumerate-table-paths $in
        | sk --preview-window right:80% --prompt 'list - choose a unique field: ' --format {$in | str join .}
      }
    }

    let finder = finders | get $type
    let column = do $finder $current $previous $IDclosure

    if $column == __return-this__ {
      return $current
    } else if $column == __prev-item__ {
      $objs = $objs | drop
    } else {
      $objs = $objs | append [($current | get $column)]
    }
  }
}

