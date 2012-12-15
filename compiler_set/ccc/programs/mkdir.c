char new_name[1024];

// parent_directory_id, entry_id, cluster_id
int resolve_result[3];

void main() {
  int cluster_id = 0;
  int new_cluster_id = 0;
  int argument_pointer = 0;
  int prev_pointer = 0;
  int empty_index = 0;

  while (argument[argument_pointer] != 0) {
    prev_pointer = argument_pointer;
    argument_pointer += basename(argument + argument_pointer, new_name);
    argument_pointer += 1;  // skip "/"
  }

  prev_pointer -= 1;
  while (prev_pointer < argument_pointer) {
    argument[prev_pointer] = 0;
    prev_pointer += 1;
  }

  resolve_argument_path(argument[ARGUMENT_HEAP_SIZE-1], argument, resolve_result);
  cluster_id   = resolve_result[2];

  // create directory
  new_cluster_id = create_fat_entry();
  empty_index    = find_empty_directory_index(cluster_id);
  create_empty_directory(new_cluster_id, cluster_id);
  create_file_entry(cluster_id, empty_index, 1, new_cluster_id, 0, new_name);

  initialize_array(argument_pointer, ARGUMENT_HEAP_SIZE, 0);
}
