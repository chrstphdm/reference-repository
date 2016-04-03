# Monkey patching Ruby's Hash class

# Merge a and b. If a and b are hashes, they are recursively merged.
# - a and b might be strings or nil. 
# - b values have the highest priority (if not nil).
def deep_merge_entries(a, b)
  if b.is_a?(Hash)
    a.is_a?(Hash) ? a.deep_merge(b) : b
  else
    b.nil? ? a : b
  end
end

# Write pretty and sorted JSON files
def write_json(filepath, data)
  def rec_sort(h)
    case h
    when Array
      h.map{|v| rec_sort(v)}#.sort_by!{|v| (v.to_s rescue nil) }
    when Hash
      Hash[Hash[h.map{|k,v| [rec_sort(k),rec_sort(v)]}].sort_by{|k,v| [(k.to_s rescue nil), (v.to_s rescue nil)]}]
    else
      h
    end
  end
  File.open(filepath, 'w') do |f|
    f.write(JSON.pretty_generate(rec_sort(data)))
  end
end

# Write sorted YAML files
def write_yaml(filepath, data)
  def rec_sort(h)
    case h
    when Array
      h.map{|v| rec_sort(v)}#.sort_by!{|v| (v.to_s rescue nil) }
    when Hash
      Hash[Hash[h.map{|k,v| [rec_sort(k),rec_sort(v)]}].sort_by{|k,v| [(k.to_s rescue nil), (v.to_s rescue nil)]}]
    else
      h
    end
  end
  File.open(filepath, 'w') do |f|
    f.write(rec_sort(data).to_yaml)
  end
end

# Extend Hash with helper methods needed to convert input data files to ruby Hash
class ::Hash

  # Recursively merge this Hash with another (ie. merge nested hash)
  # Returns a new hash containing the contents of other_hash and the contents of hash. The value for entries with duplicate keys will be that of other_hash:
  # a = {"key": "value_a"}
  # b = {"key": "value_b"}
  # a.deep_merge(b) -> {:key=>"value_b"}
  # b.deep_merge(a) -> {:key=>"value_a"}
  def deep_merge(other_hash)
    merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
    self.merge(other_hash, &merger)
  end

  # Merge keys that match "PREFIX[a-b]" with others keys that begins by "PREFIX" 
  # and that ends with x, where a<=x<=b.
  # - This is done recursively (for this Hash and every Hashes it may contain).
  # - PREFIX[a-b] values have lower priority on existing PREFIXx keys.
  # - "a" and/or "b" may be omited (ie. "PREFIX[a-]", "PREFIX[-b]" or "PREFIX[-]"), meaning that there are no lower and/or upper bound for x.
  #   * If only a is omited, a == 1.
  #   * If b is omited, only existing keys are modified (no keys are created). Otherwise, PREFIX[a] to PREFIX[b] entries are created (if missing).
  # Example:
  # {"foo-1": {a: 0}, "foo-2": {a: 0}, "foo-3": {a: 0}, "foo-[2-]": {b: 1}}.expand_square_brackets()
  #  -> {"foo-1": {a: 0}, "foo-2": {a: 0, b:1},  "foo-3": {a: 0, b: 0}}
  def expand_square_brackets(keys=self.clone)

    # Looking up for PREFIX[a-b] keys
    # (using .clone because cannot add/remove a key from hash during iteration)
    keys.clone.each { |key_ab, value_ab|

      prefix, a, b = key_ab.to_s.scan(/^(.*)\[(\d*)-(\d*)\]$/).first
      next if not a and not b # not found
      a != "" ? a = a.to_i : a = 1
      b != "" ? b = b.to_i : b

      if b != ""

        # Merge keys, creating missing entries if needed.
        (a..b).each { |x|
          key = "#{prefix}#{x}"
          key = key.to_sym if key_ab.is_a?(Symbol)

          # For duplicate entries, the value of PREFIXx is kept.
          self[key] = deep_merge_entries(deep_copy(value_ab), self[key]).clone
        }

      else

        # Modify only existing keys. Looking up for PREFIXx keys.
        self.clone.each { |key_x, value_x|
          next if key_x.class != key_ab.class
          x = key_x.to_s.scan(/^#{prefix}(\d*)$/).first
          x = x.first if x
          next if not x or x.to_i < a

          # For duplicate entries, the value of PREFIXx is kept.
          self[key_x] = deep_merge_entries(deep_copy(value_ab), value_x).clone
        }
      end
          
      # Delete entry "PREFIX[a-b]"
      self.delete(key_ab)
      keys.delete(key_ab)
    }

    # Do it recursivly
    keys.each { |key, value|
      if value.is_a?(Hash)
        self[key].expand_square_brackets(value)
      end
    }
  end

  # sort a hash according to the position of the key in the array.
  def sort_by_array(array)
    Hash[sort_by{|key, _| array.index(key) || length}] 
  end

  # Add an element composed of nested Hashes made from elements found in "array" argument
  # i.e.: from_array([a, b, c],"foo") -> {a: {b: {c: "foo"}}}
  def self.from_array(array, value)
    return array.reverse.inject(value) { |a, n| { n => a } }
  end

  # Custom iterator. Same as "each" but it sorts keys by node_uid (ie. graphene-10 after graphene-9)
  def each_sort_by_node_uid
    self.sort_by { |item| item.to_s.split(/(\d+)/).map { |e| [e.to_i, e] } }.each { |key, value|
      yield key, value if key != nil
    }
  end

  # Custom iterator. Only consider entries corresponding to cluster_list and node_list. Sorted by node_uid.
  def each_filtered_node_uid(cluster_list, node_list)
    self.each_sort_by_node_uid { |node_uid, properties| 
      cluster_uid = node_uid.split(/-/).first
      
      if (! cluster_list || cluster_list.include?(cluster_uid)) &&
          (! node_list || node_list.include?(node_uid))
        yield node_uid, properties
      end
    }
  end

  def deep_copy(o)
    Marshal.load(Marshal.dump(o))
  end

end
