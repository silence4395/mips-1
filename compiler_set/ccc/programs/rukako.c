#define ATOM_LENGTH 32
#define ATOM_COUNT 256
#define CONS(x, y) (((x) << 16) + (y))
#define CAR(c) (expression[c] >> 16)
#define CDR(c) ((expression[c] << 16) >> 16)
#define CADR(c) (CAR((CDR(c))))
#define CDAR(c) (CDR((CAR(c))))
#define CDDR(c) (CDR((CDR(c))))
#define CAAR(c) (CAR((CAR(c))))
#define CAADR(c) (CAR(CAR(CDR(c))))
#define CADDR(c) (CAR(CDR(CDR(c))))
#define CADAR(c) (CAR(CDR(CAR(c))))
#define ATOM(x) (expression[x] < 0xffff)
#define GEN_ATOM(x) (x)
#define NTH_ATOM(x) ((x) << 6)
#define NILP(x) (x == 0)
#define LISTP(x) (!ATOM(x) || expression[x] == L_NIL)
#define SET_BIT(x) ((x) + (1 << 31))
#define REMOVE_BIT(x) ((x) - (1 << 31))

#define L_NIL      0
#define L_CAR      1
#define L_CDR      2
#define L_CONS     3
#define L_QUOTE    4
#define L_EQ       5
#define L_ATOM     6
#define L_COND     7
#define L_PRINT    8
#define L_T        9
#define L_LAMBDA  10
#define L_LABEL   11
#define L_APPLY   12

#define TOO_MANY_INPUT        0xf01
#define TOO_MANY_EXP          0xf02
#define TOO_MANY_ATOM         0xf03
#define INVALID_PARAM         0xf04
#define TOO_DEEP_CALL         0xf05
#define NEGATIVE_CALL_DEPTH   0xf06
#define LIST_EXPECTED         0xf07
#define NOT_LAMBDA            0xf08
#define INVALID_LABEL_NAME    0xf09
#define FUNCTION_NOT_FOUND    0xf0a
#define R_PAREN_NOT_FOUND     0xf0b

#define DEBUG 0

int str_equal(char * str1, char * str2, int length);
int copy_string(char *dest, char * src);
int copy_n_string(char *dest, char * src, int length);

int evaluate_cond(int exp_id);
int parse_input(int id);
int evaluate(int exp_id);

char l_nil[32]    = "nil";
char l_car[32]    = "car";
char l_cdr[32]    = "cdr";
char l_cons[32]   = "cons";
char l_quote[32]  = "quote";
char l_eq[32]     = "eq";
char l_atom[32]   = "atom";
char l_cond[32]   = "cond";
char l_print[32]  = "print";
char l_t[32]      = "t";
char l_lambda[32] = "lambda";
char l_label[32]  = "label";
char l_apply[32]  = "apply";

char parse_error_message[32] = "Parse error";

int input_pointer = 0;
int exp_counter = 0;
int atom_counter = 0;
int output_pointer = 0;
int indent = 0;
int call_depth = 0;

char id_map[8192];
char input[4096];
int env[4096]; // id -> id
int expression[32768];

char output[1024];

int exp_id() {
  if (exp_counter >= 32768) {
    error(TOO_MANY_EXP);
  }
  exp_counter += 1;
  return exp_counter;
}

int atom_id() {
  if (atom_counter >= 256) {
    error(TOO_MANY_ATOM);
    return -1;
  }
  atom_counter += 1;
  return atom_counter;
}

void read_input_rs() {
  int i = 0;
  int byte = 0;
  while (i < 1024) {
    byte = inputb();
    if (byte == '\n') {
      break;
    }
    input[i] = byte;
    i += 1;
  }
  if (i >= 1024) {
    error(TOO_MANY_INPUT);
  }
}

// parent_directory_id, entry_id, cluster_id
int resolve_result[3];
int read_input_file() {
  int directory_id = 0;
  int entry_id = 0;
  int cluster_id = 0;
  int file_size = 0;

  if (resolve_argument_path(argument[ARGUMENT_HEAP_SIZE-1], argument, resolve_result) == -1) {
    return -1;
  }
  directory_id = resolve_result[0];
  entry_id     = resolve_result[1];
  cluster_id   = resolve_result[2];

  file_size = get_file_size(directory_id, entry_id);
  if (file_size >= 1024) {
    error(TOO_MANY_INPUT);
  }
  read_file(cluster_id, file_size, input);

  return 0;
}

void reconstruct_list(int exp_id) {
  if (expression[exp_id] == L_NIL) {
    return;
  }
  output[output_pointer] = ' ';
  output_pointer += 1;
  reconstruct(CAR(exp_id));
  if (LISTP(CDR(exp_id))) {
    reconstruct_list(CDR(exp_id));
  } else {
    output[output_pointer] = ' ';
    output[output_pointer + 1] = '.';
    output[output_pointer + 2] = ' ';
    output_pointer += 3;

    reconstruct(CDR(exp_id));
  }
}

void reconstruct(int exp_id) {
  if (ATOM(exp_id)) {
    output_pointer += copy_string(output + output_pointer, id_map + NTH_ATOM(expression[exp_id]));
  } else {
    output[output_pointer] = '(';
    output_pointer += 1;

    reconstruct(CAR(exp_id));

    if (LISTP(CDR(exp_id))) {
      reconstruct_list(CDR(exp_id));
    } else {
      output[output_pointer] = ' ';
      output[output_pointer + 1] = '.';
      output[output_pointer + 2] = ' ';
      output_pointer += 3;

      reconstruct(CDR(exp_id));
    }

    output[output_pointer] = ')';
    output_pointer += 1;
  }
}

void print(int top_id) {
  output_pointer = 0;
  while (output_pointer < (indent << 1)) {
    output[output_pointer] = ' ';
    output_pointer += 1;
  }
  reconstruct(top_id);
  output[output_pointer] = '\n';

  initialize_array(argument, ARGUMENT_HEAP_SIZE, 0);
  copy_n_string(argument, output, output_pointer);
}

int eval_args(int args) {
  while(!NILP(expression[args])) {
    evaluate(CAR(args));
    args = CDR(args);
  }
}

int update_environment(int params, int args) {
  while(!NILP(expression[params]) && !NILP(expression[args])) {
    if (ATOM(CAR(params))) {
      env[(call_depth << 8) + expression[CAR(params)]] = SET_BIT(expression[CAR(args)]);
    } else {
      print(params);
      error(INVALID_PARAM);
    }
    params = CDR(params);
    args = CDR(args);
  }
}

int move_exp(int exp_id) {
  int new_id = exp_id();
  if (ATOM(exp_id)) {
    expression[new_id] = expression[exp_id];
  } else {
    expression[new_id] = CONS(move_exp(CAR(exp_id)), move_exp(CDR(exp_id)));
  }
  return new_id;
}

int before_call() {
  call_depth += 1;
  if (call_depth >= 16) {
    error(TOO_DEEP_CALL);
  }
}

int after_call() {
  call_depth -= 1;
  if (call_depth < 0) {
    error(NEGATIVE_CALL_DEPTH);
  }
}

int find_env(int exp_id) {
  int level = call_depth;
  int found = L_NIL;

  while (level >= 0) {
    found = env[(level << 8) + expression[exp_id]];
    if (!NILP(found)){
      return found;
    }
    level -= 1;
  }
  return L_NIL;
}

int evaluate(int exp_id) {
  if (DEBUG) {
    print(exp_id);
    indent += 1;
  }

  if (ATOM(exp_id)) {
    int found = find_env(exp_id);
    if (!NILP(found)) {
      expression[exp_id] = REMOVE_BIT(found);
    }
  } else {
    switch (expression[CAR(exp_id)]) {
    // car
    case 1:
      evaluate(CADR(exp_id));
      if (ATOM(CADR(exp_id))) {
        error(LIST_EXPECTED);
      }
      expression[exp_id] = expression[CAADR(exp_id)];
      break;

    // cdr
    case 2:
      evaluate(CADR(exp_id));
      if (ATOM(CADR(exp_id))) {
        error(LIST_EXPECTED);
      }
      expression[exp_id] = expression[CDR(CADR(exp_id))];
      break;

    // cons
    case 3:
      evaluate(CADR(exp_id));
      evaluate(CADDR(exp_id));
      expression[exp_id] = CONS(CADR(exp_id), CADDR(exp_id));
      break;

    // quote
    case 4:
      expression[exp_id] = expression[CADR(exp_id)];
      break;

    // eq
    case 5:
      evaluate(CADR(exp_id));
      evaluate(CADDR(exp_id));
      if (expression[CADR(exp_id)] == expression[CADDR(exp_id)]) {
        expression[exp_id] = L_T;
      } else {
        expression[exp_id] = L_NIL;
      }
      break;

    // atom
    case 6:
      evaluate(CADR(exp_id));
      if (ATOM(CADR(exp_id))) {
        expression[exp_id] = L_T;
      } else {
        expression[exp_id] = L_NIL;
      }
      break;

    // cond
    case 7:
      evaluate_cond(CDR(exp_id));
      expression[exp_id] = expression[CDR(exp_id)];
      break;

    // print
    case 8:
      evaluate(CADR(exp_id));
      print(CADR(exp_id));
      expression[exp_id] = expression[CADR(exp_id)];
      break;

    // apply
    case 12:
      {
        int callee = CADR(exp_id);
        int args = CDDR(exp_id);

        eval_args(args);

        before_call();

        // if expression stack is not sufficient,
        // you can save and restore max id here
        if (expression[CAR(callee)] == L_LAMBDA) {
          int new_exp_id = move_exp(CADDR(callee));
          update_environment(CADR(callee), args);
          evaluate(new_exp_id);
          expression[exp_id] = expression[new_exp_id];

        } else if (expression[CAR(callee)] == L_LABEL) {
          int lambda_name = CADR(callee);
          int lambda = CADDR(callee);
          int new_exp_id = 0;

          if (ATOM(lambda_name)) {
            env[(call_depth << 8) + expression[lambda_name]] = SET_BIT(expression[lambda]);
          } else {
            error(INVALID_LABEL_NAME);
          }

          new_exp_id = move_exp(CADDR(lambda));
          update_environment(CADR(lambda), args);
          evaluate(new_exp_id);
          expression[exp_id] = expression[new_exp_id];

        } else {
          error(NOT_LAMBDA);
        }

        after_call();
      }
      break;

    default:
      {
        int found = find_env(CAR(exp_id));
        if (!NILP(found)) {
          int cdr = (REMOVE_BIT(found) << 16) >> 16;
          int new_exp_id = 0;
          int args = CDR(exp_id);

          eval_args(args);

          before_call();

          new_exp_id = move_exp(CADR(cdr));

          update_environment(CAR(cdr), args);
          evaluate(new_exp_id);
          expression[exp_id] = expression[new_exp_id];

          after_call();
        } else {
          print(exp_id);
          error(FUNCTION_NOT_FOUND);
        }
      }
      break;
    }
  }
  if (DEBUG) {
    indent -= 1;
    print(exp_id);
  }
}

int evaluate_cond(int exp_id) {
  if (NILP(expression[exp_id])) {
    return;
  } else {
    evaluate(CAAR(exp_id));
    if (!NILP(expression[CAAR(exp_id)])) {
      evaluate(CADAR(exp_id));
      expression[exp_id] = expression[CADAR(exp_id)];
    } else {
      evaluate_cond(CDR(exp_id));
      expression[exp_id] = expression[CDR(exp_id)];
    }
  }
}

void skip_space() {
  int c = 0;
  while (1) {
    c = input[input_pointer];
    if (c != ' ' && c != '\n' && c != 0x09) {
      break;
    }
    input_pointer += 1;
  }
}

int parse_list(int id) {
  int left = exp_id();
  int right = exp_id();
  if (input[input_pointer] == ')') {
    expression[right] = L_NIL;
  } else {
    expression[id] = CONS(left, right);
    if (parse_input(left) == -1) {
      return -1;
    }
    skip_space();
    if (parse_list(right) == -1) {
      return -1;
    }
  }
  return 0;
}

int parse_input(int id) {
  int exp_start = input_pointer;

  if (input[exp_start] == '(') {
    // read S expression
    int left = exp_id();
    int right = exp_id();
    expression[id] = CONS(left, right);
    input_pointer += 1;
    skip_space();
    if (parse_input(left) == -1) {
      return -1;
    }
    skip_space();
    if (input[input_pointer] == '.') {
      input_pointer += 1;
      skip_space();
      if (parse_input(right) == -1) {
        return -1;
      }
      skip_space();
    } else {
      if (parse_list(right) == -1) {
        return -1;
      }
    }
    if (input[input_pointer] == ')') {
      input_pointer += 1;
    } else {
      error(R_PAREN_NOT_FOUND);
      return -1;
    }
    skip_space();

  } else {
    // read ATOM
    int length = 0;
    int atom_pointer = 0;
    int new_id = atom_id();

    if (new_id == -1) {
      return -1;
    }

    while (input[input_pointer] != ' '
           && input[input_pointer] != ')') {
      length += 1;
      input_pointer += 1;
    }

    while (atom_pointer <= atom_counter) {
      if (str_equal(id_map + NTH_ATOM(atom_pointer), input + exp_start, length)
          && id_map[NTH_ATOM(atom_pointer) + length] == 0) {
        expression[id] = GEN_ATOM(atom_pointer);
        return 0;
      }
      atom_pointer += 1;
    }

    // undefined atom
    copy_n_string(id_map + NTH_ATOM(new_id), input + exp_start, length);
    expression[id] = GEN_ATOM(new_id);
  }

  return 0;
}

int main() {
  // predefined functions
  copy_string(id_map + NTH_ATOM(L_NIL), l_nil);
  copy_string(id_map + NTH_ATOM(L_CAR), l_car);
  copy_string(id_map + NTH_ATOM(L_CDR), l_cdr);
  copy_string(id_map + NTH_ATOM(L_CONS), l_cons);
  copy_string(id_map + NTH_ATOM(L_QUOTE), l_quote);
  copy_string(id_map + NTH_ATOM(L_EQ), l_eq);
  copy_string(id_map + NTH_ATOM(L_ATOM), l_atom);
  copy_string(id_map + NTH_ATOM(L_COND), l_cond);
  copy_string(id_map + NTH_ATOM(L_PRINT), l_print);
  copy_string(id_map + NTH_ATOM(L_T), l_t);
  copy_string(id_map + NTH_ATOM(L_LAMBDA), l_lambda);
  copy_string(id_map + NTH_ATOM(L_LABEL), l_label);
  copy_string(id_map + NTH_ATOM(L_APPLY), l_apply);


  atom_counter = L_APPLY;

  if (argument[0] == 0) {
    read_input_rs();
  } else {
    debug(argument[0]);
    if (read_input_file() == -1) {
      copy_string(argument, file_not_found_error_message);
      return 1;
    }
  }

  input_pointer = 0;
  if (parse_input(0) == -1) {
    copy_string(argument, parse_error_message);
    return 1;
  }

  evaluate(0);
  return;
}
