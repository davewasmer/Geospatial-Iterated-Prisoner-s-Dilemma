import processing.video.*;

class Cell {
  int cell_id;
  int x;
  int y;
  int strategy_id;

  int round_score = 0;
  int score = 0;

  boolean just_captured = false;
  int new_strategy_id;
  Cell captor;

  HashMap history = new HashMap();

  HashMap data = new HashMap();

  ArrayList get_history_with(Cell c)
  {
    if (!c.history.containsKey(str(cell_id)))  c.history.put(str(cell_id), new ArrayList());

    return (ArrayList) c.history.get(str(cell_id));
  }

  void clear_history_with(Cell c)
  {
    if (history.containsKey(str(c.cell_id)))
    {
      ArrayList h = (ArrayList)history.get(str(c.cell_id));
      h.clear();
    }
  }
}

// Used to generate unique identifers for each cell
int cell_counter = 0;

// Hashmap with all config options
HashMap config = new HashMap();

// Playing grid
Cell[][] grid;

// Round timer
int last_round_time = 0;

// Currently selected cell
int mouse_cell_x;
int mouse_cell_y;

int active_cell_x;
int active_cell_y;

PFont arial_14;
PFont arial_24;

ArrayList captured_list = new ArrayList();

boolean paused = true;

boolean mouse_pressed_previous = false;
boolean key_pressed_previous = false;

PVector pause_button_size;
PVector pause_button_position;

PVector next_button_size;
PVector next_button_position;

// used to play a single round only
boolean play_round = false;

int round_count = 0;

int[][] grid_map;

ArrayList film = new ArrayList();

int[][] current_film_frame;

PrintWriter savewriter;

String film_name = day()+"-"+month()+" "+hour()+"-"+minute()+"-"+second();

ArrayList capture_list = new ArrayList();

MovieMaker moviesaver = null;;
int num_movies = 1;

int last_movie_save = 0;

float max_score = 0;
float min_score = 0;

String[] strategy_names = { "Adaptive", "All Cooperate", "All Defect", "Gradual", "Grudger", "Pavlov", "Punisher", "Random", "Tit For Tat",
      "Tit For Tat Forgiving", "Tit For Tat Probing", "Tit For Tat Random", "Tit For Tat Suspicious",  "Tit For Two Tats" };

void setup()
{
  // Load the configuration file
  load_config();
  // Setup the Processing environment
  setup_environment();
  // Create GUI
  create_gui();
  // Create the grid of cells
  create_grid();
}

void setup_environment()
{
  colorMode(HSB);
  background(128);
  int screen_width = (int(config("grid width")) * int(config("cell width"))) + 350;
  int screen_height = (int(config("grid height")) * int(config("cell height"))) + 200;
  //size(screen_width, screen_height, P3D);
  size(640,480,P3D);
  arial_14 = loadFont("ArialMT-14.vlw");
  arial_24 = loadFont("Arial-24.vlw");
  //moviesaver = new MovieMaker(this, screen_width, screen_height, film_name+".mov", int(config("rounds per second")), MovieMaker.ANIMATION, MovieMaker.LOW);
}

void load_config()
{
  // Load the config file as array of lines
  String[] config_strings = loadStrings("config.txt");

  // Loop through the config statements
  for (int i = 0; i < config_strings.length; i++)
  {
    String ln = config_strings[i];

    // Pass over comments and blank lines
    if (ln.length() == 0 || ln.charAt(0) == '#') continue;

    // Get token and value
    String[] key_value = split(ln,'=');

    // Error handling for badly formed lines
    if (key_value.length != 2) println("Error reading config file - bad format at line "+(i+1));

    // Account for whitespace
    key_value[0] = trim(key_value[0]);
    key_value[1] = trim(key_value[1]);

    // Add to config hash
    config.put(key_value[0], key_value[1]);
  }
}

void load_map()
{
  String[] map_strings = loadStrings("map.txt");

  grid_map = new int[grid_width()][grid_height()];

  // Loop through the config statements
  for (int y = 0; y < grid_height(); y++)
  {
    String ln = map_strings[y];

    // Pass over comments and blank lines
    if (ln.length() == 0 || ln.charAt(0) == '#') continue;

    String[] row_items = splitTokens(ln);

    for (int x = 0; x < grid_width(); x++)
    {
      grid_map[x][y] = int(row_items[x]);
    }
  }
}

String config(String key)
{
  return (String)config.get(key);
}

void create_gui()
{
  pause_button_size = new PVector(68,21);
  next_button_size = new PVector(95,20);

  pause_button_position = new PVector(10, map_height() + 10);
  next_button_position = new PVector(pause_button_position.x + pause_button_size.x + 5, pause_button_position.y);
}

void create_grid()
{
  int width = int(config("grid width"));
  int height = int(config("grid height"));

  grid = new Cell[height][width];

  if (boolean(config("predefined map"))) load_map();

  for (int x = 0; x < width; x++)
  {
    for (int y = 0; y < height; y++)
    {
      grid[y][x] = new Cell();
      init_cell(grid[y][x], x, y);
    }
  }
}

void init_cell(Cell c, int x, int y)
{
  cell_counter++;
  c.cell_id = cell_counter;
  c.x = x;
  c.y = y;

  if (boolean(config("predefined map"))) c.strategy_id = grid_map[x][y];
  else c.strategy_id = int(random(1,15));
}


int grid_width()
{
  return int(config("grid width"));
}

int grid_height()
{
  return int(config("grid height"));
}

int map_width()
{
  return int(config("grid width")) * int(config("cell width"));
}

int map_height()
{
  return int(config("grid height")) * int(config("cell height"));
}

boolean rectangle_contains_point(PVector point, PVector rect_position, PVector rect_size)
{
  if (point.x > rect_position.x && point.x < rect_position.x + rect_size.x)
  {
    if (point.y > rect_position.y && point.y < rect_position.y + rect_size.y)
    {
      return true;
    }
  }
  return false;
}

void draw()
{
  clear_screen();

  boolean played = false;
  // Round timer
  if ((millis() - last_round_time > 1000/int(config("rounds per second")) && !paused) || play_round)
  {
    round_count++;
    //println("");
    //println("######## Start round "+round_count+" at "+millis()+" ########");
    if (play_round) play_round = false;

    // Reset time
    last_round_time = millis();

    // Play round
    play();

    played = true;
  }

  draw_cells();

  update_gui();

  user_controlled_cell();

  check_save_film();

  check_save_movie();

  check_debug();

  update_previous_input_state();

  if (played)
  {
    if (moviesaver == null) moviesaver = new MovieMaker(this, width, height, "films/"+film_name+" "+num_movies+".mov", int(config("rounds per second")), MovieMaker.ANIMATION, MovieMaker.LOW);
    moviesaver.addFrame();
  }
}

void update_previous_input_state()
{
  mouse_pressed_previous = mousePressed;
  key_pressed_previous = keyPressed;
}

void check_save_movie()
{
  if ((keyPressed && key == 'm' && !key_pressed_previous) || (millis() - last_movie_save > 300000))
  {
    println("saving movie");
    moviesaver.finish();
    num_movies++;
    last_movie_save = millis();
    moviesaver = null;
  }
}

void user_controlled_cell()
{
  if (active_cell_x != -1 && active_cell_y != -1 && active_cell().strategy_id == 15)
  {
    if (keyPressed && key == 'd')
    {
      active_cell().data.put("user_defects","true");
    }
  }
}

void check_save_film()
{
 if (keyPressed && key == 's' && !key_pressed_previous)
 {
   save_film();
 }
}

void check_debug()
{
 if (keyPressed && key == 'q' && !key_pressed_previous)
 {
   /*ArrayList n = get_cell_neighbors(mouse_cell());
   for ( int i = 0; i < n.size(); i++)
   {
     Cell c = (Cell) n.get(i);
     if (c.strategy_id != mouse_cell().strategy_id)
     {
       highlight_cell(c.x,c.y,color(255));
       println("Score Difference: "+(c.score - mouse_cell().score));
     }
   }
   /*  Compare scores

   println("Comparing active cell and mouse cell");
   println("  Active cell score = "+active_cell().score);
   println("  Mouse cell score = "+mouse_cell().score);
   println("  Difference = "+(active_cell().score - mouse_cell().score));
   */

   Cell c = mouse_cell();
   print("Mouse is over:");
   print("("+c.x+","+c.y+")");
   print("****");
 }
}

void clear_screen()
{
  noStroke();
  background(255);
}

void update_gui()
{
  //update_mouse_cell();
  //update_active_cell();
  //highlight_active_cell();
  //highlight_mouse_cell();

  //draw_cell_info();

  //draw_pause_button();
  //check_pause_button();
  //draw_next_button();
  //check_next_button();
  check_pause_key();
  //update_strategy_list();
}

void highlight_cells_by_strategy(int id)
{
  for (int x = 0; x < int(config("grid width")); x++)
  {
    for (int y = 0; y < int(config("grid height")); y++)
    {
      if (grid[y][x].strategy_id == id + 1) highlight_cell(x, y, color(255));
    }
  }
}

void update_strategy_list()
{
  fill(128);
  textFont(arial_14);
  int startx = 10;
  int starty = map_height() + 50;
  for (int i = 0; i <  8; i++)
  {
    text(strategy_names[i], startx, starty + (15 * i));
    if (rectangle_contains_point(new PVector(mouseX, mouseY), new PVector(startx, starty + (15 * i) - 15), new PVector(100,15)))
    {
      highlight_cells_by_strategy(i);
    }
  }
  startx += 100;
  for (int i = 8; i < strategy_names.length; i++)
  {
    text(strategy_names[i], startx, starty + (15 * (i - 8)));
    if (rectangle_contains_point(new PVector(mouseX, mouseY), new PVector(startx, starty - 15 + (15 * (i - 8))), new PVector(100,15)))
    {
      highlight_cells_by_strategy(i);
    }
  }
}

void check_next_button()
{
  if (mousePressed && !mouse_pressed_previous)
  {
    if (rectangle_contains_point(new PVector(mouseX, mouseY), next_button_position, next_button_size))
    {
      println("playing one round");
      play_round = true;
    }
  }
}

void draw_next_button()
{
  noStroke();
  fill(0xFF00FF00);
  rect(next_button_position.x, next_button_position.y, next_button_size.x, next_button_size.y);
  fill(0);
  textFont(arial_14);
  text("Next Round", next_button_position.x + 10, next_button_position.y + 15);
}

void check_pause_key()
{
  if (keyPressed && key == ' ' && !key_pressed_previous)
 {
   paused = !paused;
 }
}

void check_pause_button()
{
  if (mousePressed && !mouse_pressed_previous)
  {
    if (rectangle_contains_point(new PVector(mouseX, mouseY), pause_button_position, pause_button_size))
    {
      println("pause pressed, pause now equals '"+paused+"'");
      paused = !paused;
    }
  }
}

void draw_pause_button()
{
  String btntxt;
  if (paused)
  {
    fill(0xFFFF0000);
    btntxt = "Paused";
  }
  else
  {
    fill(0xFF00FF00);
    btntxt = "Playing";
  }
  noStroke();
  rect(pause_button_position.x, pause_button_position.y, pause_button_size.x, pause_button_size.y);
  textFont(arial_14);
  fill(0);
  text(btntxt, pause_button_position.x + 10, pause_button_position.y + 15);
}

void draw_cell_info()
{

  int x = int(config("grid width")) * int(config("cell width"));

  textFont(arial_14);
  fill(128);
  text("Active Cell", x + 20, 15);
  stroke(128);
  strokeWeight(1);
  line(x + 100, 10, x + 250, 10);

  if (active_cell() != null)
  {
    fill(0);
    textFont(arial_24);
    text(get_strategy_name(active_cell().strategy_id), x + 20, 40);

    fill(128);
    textFont(arial_14);
    text("Total Score: "+active_cell().score, x + 20, 60);
  }

  int y = 100;

  textFont(arial_14);
  fill(128);
  text("Cursor Cell", x + 20, y + 5);
  stroke(128);
  strokeWeight(1);
  line(x + 110, y, x + 250, y);


  if (mouse_cell() != null)
  {
    fill(0);
    textFont(arial_24);
    text(get_strategy_name(mouse_cell().strategy_id), x + 20, y + 30);

    fill(128);
    textFont(arial_14);
    text("Total Score: "+mouse_cell().score, x + 20, y + 50);
  }
}

void update_active_cell()
{
  if (mousePressed)
  {
    if (mouse_cell_x >= 0 && mouse_cell_y >= 0)
    {
      active_cell_x = mouse_cell_x;
      active_cell_y = mouse_cell_y;
    }
  }
}

void highlight_cell(int x, int y, color c)
{
    stroke(c);
    strokeWeight(2);

    int startX = x * int(config("cell width"));
    int startY = y * int(config("cell height"));

    line(startX, startY, startX + int(config("cell width")), startY);
    line(startX + int(config("cell width")), startY, startX + int(config("cell width")), startY + int(config("cell height")));
    line(startX + int(config("cell width")), startY + int(config("cell height")), startX, startY + int(config("cell height")));
    line(startX, startY + int(config("cell height")), startX, startY);
}

void highlight_active_cell()
{
  if (active_cell_x >= 0 && active_cell_y >= 0)
  {
    highlight_cell(active_cell_x, active_cell_y, color(255));
  }
}

Cell mouse_cell()
{
  if (mouse_cell_x != -1 && mouse_cell_y != -1) return grid[mouse_cell_y][mouse_cell_x];
  else return null;
}

Cell active_cell()
{
  if (active_cell_x != -1 && active_cell_y != -1)  return grid[active_cell_y][active_cell_x];
  else return null;
}

void highlight_mouse_cell()
{
  if (mouse_cell_x >= 0 && mouse_cell_y >= 0)
  {
    highlight_cell(mouse_cell_x, mouse_cell_y, color(255));
  }
}

void update_mouse_cell()
{
  if (mouseX < int(config("grid width")) * int(config("cell width")))
  {
    if (mouseY < int(config("grid height")) * int(config("cell height")))
    {
      mouse_cell_x = floor( mouseX / int(config("cell width")) );
      mouse_cell_y = floor( mouseY / int(config("cell height")) );
    }
    else
    {
      mouse_cell_x = -1;
      mouse_cell_y = -1;
    }
  }
  else
  {
    mouse_cell_x = -1;
    mouse_cell_y = -1;
  }
}

float xmag, ymag, newXmag, newYmag = 0;

void draw_cells()
{
  stroke(32,32,32,50);
  strokeWeight(2);

  float score_range = max_score - min_score;
  //pushMatrix();
  //translate(map_width()/2, map_height()/2, 0);
  pushMatrix();
  translate((width/2)-(map_width()/2)+250,(height/2)-(map_height()/2)-150,-400);
  rotateX(1);

  float rz =  (mouseX*100)/width;
  //rotateZ((rz/100));
  rotateZ(1.1);

  float ry = (mouseY*100)/width;
  rotateY((ry/100)-.2);

  scale(2);


  int width = int(config("grid width"));
  int height = int(config("grid height"));
  int cell_width = int(config("cell width"));
  int cell_height = int(config("cell height"));

  float score_percent;

  for (int x = 0; x < width; x++)
  {
    for (int y = 0; y < height; y++)
    {
      score_percent = (grid[y][x].score - min_score) / score_range;

  	  strategy_color(grid[y][x].strategy_id);

  	  float h;
  	  if (score_range == 0) h = 1;
  	  else
  	  {
  	    h = (score_percent * 50);
  	  }

      translate(0, cell_height, h/2);
      box(cell_width, cell_height, h);
      translate(0,0,-h/2);
    }
    translate(cell_width, -(cell_height * height), 0);
  }
  popMatrix();
 // popMatrix();
}

void strategy_color(int id)
{
  colorMode(HSB);
  int l;
  if (id%2 == 0) l = 255;
  else l = 128;
  int h = (255/14)*id;
  fill(h,255,l,255);
}

void begin_film_frame()
{
  current_film_frame = new int[grid_width()][grid_height()];
}

void record_film(Cell c)
{
  current_film_frame[c.x][c.y] = c.strategy_id;// "("+str(c.strategy_id)+" "+str(c.score)+")";
}

void end_film_frame()
{
  film.add(current_film_frame);
  current_film_frame = null;

  if (film.size() > 100)
  {
    save_film();
  }
}

void save_film()
{
  savewriter = createWriter(film_name+".txt");
  for (int i = 0; i < film.size(); i++)
  {
    savewriter.println("");
    savewriter.println("#### Frame "+i+" ####");
    int[][] frame = (int[][])film.get(i);
    for (int y = 0; y < grid_height(); y++)
    {
      for (int x = 0; x < grid_width(); x++)
      {
        savewriter.print(grid[y][x].strategy_id+" ");
      }
      savewriter.println("");
    }
  }
  savewriter.flush();
  savewriter.close();
}

// Generates the pairs of playing partners and plays them
void play()
{
  capture_list.clear();
  int width = int(config("grid width"));
  int height = int(config("grid height"));

  for (int x = 0; x < width; x++)
  {
    for (int y = 0; y < height; y++)
    {
      if (y < height - 1) play_pair(grid[y][x], grid[y + 1][x]);
      else if (boolean(config("infinite map"))) play_pair(grid[y][x], grid[0][x]);
    }
  }

  for (int y = 0; y < height; y++)
  {
    for (int x = 0; x < width; x++)
    {
      if (x < width - 1) play_pair(grid[y][x], grid[y][x + 1]);
      else if (boolean(config("infinite map"))) play_pair(grid[y][x], grid[y][0]);
    }
  }

  begin_film_frame();
  for (int x = 0; x < width; x++)
  {
    for (int y = 0; y < height; y++)
    {
      finish_round(grid[y][x]);
      record_film(grid[y][x]);
    }
  }

  max_score = 0;
  min_score = 99999999;
  for (int x = 0; x < width; x++)
  {
    for (int y = 0; y < height; y++)
    {
      check_capture(grid[y][x]);
      if (grid[y][x].score > max_score) max_score = grid[y][x].score;
      if (grid[y][x].score < min_score) min_score = grid[y][x].score;
    }
  }

  for (int i = 0; i < capture_list.size(); i++)
  {
    Cell c = (Cell)capture_list.get(i);
    convert_cell(c);
    record_film(c);
  }
  end_film_frame();
}

String get_strategy_name(int id)
{
  return strategy_names[id - 1];
}

// Plays an individual pair of cells against each other
void play_pair(Cell c1, Cell c2)
{
  //println("("+c1.x+","+c1.y+") vs. ("+c2.x+","+c2.y+")");


  //print("    "+get_strategy_name(c1.strategy_id)+" chooses to ");

  // Cell 1 decides action
  boolean c1_choice = false;
  switch (c1.strategy_id)
  {
  	case 1:
  		c1_choice = Adaptive(c1, c2);
  		break;
  	case 2:
  		c1_choice = AllCooperate(c1, c2);
  		break;
  	case 3:
  		c1_choice = AllDefect(c1, c2);
  		break;
  	case 4:
  		c1_choice = Gradual(c1, c2);
  		break;
  	case 5:
  		c1_choice = Grudger(c1, c2);
  		break;
  	case 6:
  		c1_choice = Pavlov(c1, c2);
  		break;
  	case 7:
  		c1_choice = Punisher(c1, c2);
  		break;
  	case 8:
  		c1_choice = Random(c1, c2);
  		break;
  	case 9:
  		c1_choice = TitForTat(c1, c2);
  		break;
  	case 10:
  		c1_choice = TitForTatForgiving(c1, c2);
  		break;
  	case 11:
  		c1_choice = TitForTatProbing(c1, c2);
  		break;
  	case 12:
  		c1_choice = TitForTatRandom(c1, c2);
  		break;
  	case 13:
  		c1_choice = TitForTatSuspicious(c1, c2);
  		break;
  	case 14:
  		c1_choice = TitForTwoTats(c1, c2);
  		break;
  	case 15:
  		c1_choice = UserControlled(c1, c2);
  		break;
  	default:
  		println("The random strategy picker failed to generate a proper result - check your range values and number of strategies. No such strategy: "+c1.strategy_id);
  }

  //print("\n");

  //print("    "+get_strategy_name(c2.strategy_id)+" chooses to ");

  // Cell 2 decides action
  boolean c2_choice = false;
  switch (c2.strategy_id)
  {
  	case 1:
  		c2_choice = Adaptive(c2, c1);
  		break;
  	case 2:
  		c2_choice = AllCooperate(c2, c1);
  		break;
  	case 3:
  		c2_choice = AllDefect(c2, c1);
  		break;
  	case 4:
  		c2_choice = Gradual(c2, c1);
  		break;
  	case 5:
  		c2_choice = Grudger(c2, c1);
  		break;
  	case 6:
  		c2_choice = Pavlov(c2, c1);
  		break;
  	case 7:
  		c2_choice = Punisher(c2, c1);
  		break;
  	case 8:
  		c2_choice = Random(c2, c1);
  		break;
  	case 9:
  		c2_choice = TitForTat(c2, c1);
  		break;
  	case 10:
  		c2_choice = TitForTatForgiving(c2, c1);
  		break;
  	case 11:
  		c2_choice = TitForTatProbing(c2, c1);
  		break;
  	case 12:
  		c2_choice = TitForTatRandom(c2, c1);
  		break;
  	case 13:
  		c2_choice = TitForTatSuspicious(c2, c1);
  		break;
  	case 14:
  		c2_choice = TitForTwoTats(c2, c1);
  		break;
  	case 15:
  		c2_choice = UserControlled(c2, c1);
  		break;
  	default:
  		println("The random strategy picker failed to generate a proper result - check your range values and number of strategies. No such strategy: "+c2.strategy_id);
  }

  //print("\n");

  int c1_payoff = 0;
  int c2_payoff = 0;

  // Payout based on choices
  // both cooperated
  if (c1_choice && c2_choice)
  {
    c1_payoff = int(config("both cooperate payoff"));
    c2_payoff = int(config("both cooperate payoff"));
  	c1.round_score += c1_payoff;
  	c2.round_score += c2_payoff;
  }

  // c1 cooperates, c2 defects
  else if (c1_choice && !c2_choice)
  {
  	c1_payoff = int(config("suckers payoff"));
  	c2_payoff = int(config("cheaters payoff"));
  	c1.round_score += c1_payoff;
  	c2.round_score += c2_payoff;
  }

  // c1 defects, c2 cooperates
  else if (!c1_choice && c2_choice)
  {
  	c1_payoff = int(config("cheaters payoff"));
  	c2_payoff = int(config("suckers payoff"));
  	c1.round_score += c1_payoff;
  	c2.round_score += c2_payoff;
  }

  // both defected
  else if (!c1_choice && !c2_choice)
  {
  	c1_payoff = int(config("both defect payoff"));
  	c2_payoff = int(config("both defect payoff"));
  	c1.round_score += c1_payoff;
  	c2.round_score += c2_payoff;
  }


  // Record in history
  if (c1.get_history_with(c2) == null) c1.history.put(str(c2.cell_id),new ArrayList());
  ArrayList c1history = (ArrayList)c1.get_history_with(c2);
  if (c2.get_history_with(c1) == null) c2.history.put(str(c1.cell_id),new ArrayList());
  ArrayList c2history = (ArrayList)c2.get_history_with(c1);

  c1history.add(choice_name(c1_choice)+" "+c1_payoff);
  c2history.add(choice_name(c2_choice)+" "+c2_payoff);

}

String choice_name(boolean choice)
{
  if (choice) return "cooperate";
  else return "defect";
}

ArrayList get_cell_neighbors(Cell c)
{
  ArrayList neighbors = new ArrayList();

  // East
  if (c.x == 0)
  {
    if (boolean(config("infinite map"))) neighbors.add(grid[c.y][int(config("grid width")) - 1]);
  }
  else
  {
    //if (grid[c.y][c.x - 1].strategy_id != c.strategy_id) print("getting neighbors for cell ("+c.x+","+c.y+")\neast opponent found\n");
    neighbors.add(grid[c.y][c.x - 1]);
  }

  // West
  if (c.x == int(config("grid width")) - 1)
  {
    if (boolean(config("infinite map"))) neighbors.add(grid[c.y][0]);
  }
  else
  {
    //if (grid[c.y][c.x + 1].strategy_id != c.strategy_id) print("west opponent found\n");
    neighbors.add(grid[c.y][c.x + 1]);
  }

  // North
  if (c.y == 0)
  {
    if (boolean(config("infinite map"))) neighbors.add(grid[int(config("grid height")) - 1][c.x]);
  }
  else
  {
    //if (grid[c.y - 1][c.x].strategy_id != c.strategy_id) print("north opponent found\n");
    neighbors.add(grid[c.y - 1][c.x]);
  }

  // South
  if (c.y == int(config("grid height")) - 1)
  {
    if (boolean(config("infinite map"))) neighbors.add(grid[0][c.x]);
  }
  else
  {
    neighbors.add(grid[c.y + 1][c.x]);
    //if (grid[c.y + 1][c.x].strategy_id != c.strategy_id) print("south opponent found\n\n");
  }

  return neighbors;
}

void finish_round(Cell c)
{
  c.score += c.round_score;
  c.round_score = 0;
  c.just_captured = false;
}

void check_capture(Cell c)
{
  ArrayList neighbors = get_cell_neighbors(c);

  Cell dominant_neighbor = null;
  for (int i = 0; i < neighbors.size(); i++)
  {
    if (neighbors.get(i) != null)
    {
      Cell neighbor = (Cell)neighbors.get(i);
      if (neighbor.strategy_id == c.strategy_id || neighbor.just_captured) continue;

//if (c.x == 4 && c.y == 3) print("neighbor opponent ("+neighbor.x+","+neighbor.y+") is "+get_strategy_name(neighbor.strategy_id)+", while I am "+get_strategy_name(c.strategy_id)+"\n");

      if (dominant_neighbor == null) dominant_neighbor = (Cell)neighbors.get(i);
      else if (neighbor.score > dominant_neighbor.score && neighbor.strategy_id != c.strategy_id)
      {
        dominant_neighbor = neighbor;
      }

//if (c.x == 4 && c.y == 3) print("Dominant neighbor for me ("+c.x+","+c.y+") is ("+dominant_neighbor.x+","+dominant_neighbor.y+")\n");

    }
  }


  if (dominant_neighbor != null && dominant_neighbor.score - c.score > int(config("capture threshold")))
  {
    /* Capture debug information
    println("Capture!");
    println("Winner's Score: "+dominant_neighbor.score);
    println("Loser's Score: "+c.score);
    println("Score Difference: "+(dominant_neighbor.score - c.score));
    println("Capture Threshold: "+int(config("capture threshold")));
    */

    mark_cell_for_capture(c, dominant_neighbor);
  }
}

void mark_cell_for_capture(Cell loser, Cell winner)
{
  //loser.new_strategy_id = winner.strategy_id;
  loser.captor = winner;
  capture_list.add(loser);

  ArrayList neighbors = get_cell_neighbors(loser);

  for (int i = 0; i <= neighbors.size() - 1; i++)
  {
    Cell n = (Cell)neighbors.get(i);
    n.clear_history_with(loser);
  }
}

void convert_cell(Cell loser)
{
  loser.strategy_id = loser.captor.strategy_id;
  loser.history.clear();
  loser.data.clear();
  loser.just_captured = true;

  String score_behavior = (String) config("captured cell score");

  if (score_behavior.equals("retain"))
  {
    // do nothing to the score
  }
  else if (score_behavior.equals("reset"))
  {
    loser.score = 0;
  }
  else if (score_behavior.equals("copy"))
  {
    loser.score = loser.captor.score;
  }
}

boolean string_starts_with(String start_text, String text_to_search)
{
  if (text_to_search.length() > start_text.length() && text_to_search.substring(0, start_text.length()).equals(start_text)) return true;
  else return false;
}

String get_string_token(String delimiter, int token_number, String raw)
{
  String[] tokens = splitTokens(raw, delimiter);
  return tokens[token_number - 1];
}

boolean Adaptive (Cell me, Cell him)
{
  ArrayList my_history = me.get_history_with(him);

  int cooperate_score = 0;
  int defect_score = 0;
  int cooperate_count = 0;
  int defect_count = 0;

  if (my_history.size() < 8)
  {
    if (my_history.size() < 4)
    {
      //print("cooperate because it is my opening 4 moves");
      return true;
    }
    else
    {
      //print("defect because it is my 4th through 8th move");
      return false;
    }
  }
  else
  {
    for (int i = 0; i < my_history.size() - 1; i++)
    {
      String[] tokens = splitTokens(my_history.get(i).toString());
      String choice = tokens[0];
      String payoff = tokens[1];

      if (choice.equals("cooperate"))
      {
        cooperate_score += int(payoff);
        cooperate_count++;
      }
      else if (choice.equals("defect"))
      {
        defect_score += int(payoff);
        defect_count++;
      }
      else
      {
        println("Error - unknown history entry encountered - can only handle 'cooperate' or 'defect'");
      }
    }
  }

  if (cooperate_score / cooperate_count > defect_score / defect_count)
  {
    //print("cooperate because the average payout is "+(cooperate_score / cooperate_count)+" compared to defect's avg. payout of "+(defect_score / defect_count));
    return true;
  }
  else
  {
    //print("defect because the average payout is "+(defect_score / defect_count)+" compared to cooperates's avg. payout of "+(cooperate_score / cooperate_count));
    return false;
  }
}

boolean AllCooperate (Cell me, Cell him)
{
  //print("cooperate. It's what I do!");
  return true;
}

boolean AllDefect (Cell me, Cell him)
{
  //print("defect. It's what I do!");
  return false;
}

boolean Gradual (Cell me, Cell him)
{
  ArrayList my_history = me.get_history_with(him);
  ArrayList his_history = him.get_history_with(me);

  if (my_history.size() == 0) return true;

  String his_last_move = his_history.get(his_history.size() - 1).toString();
  String my_last_move = my_history.get(my_history.size() - 1).toString();

  // If we are in punishing mode
  if (me.data.containsKey("punishing") && boolean(me.data.get("punishing").toString()))
  {
    // Check to see if we have already punished the same number of times as he defected
    if (int(me.data.get("current punish count").toString()) >= int(me.data.get("total punish count").toString()))
    {
      // We have, so now check it we have added the extra cooperation at the end
      if (int(me.data.get("current punish count").toString()) < int(me.data.get("total punish count").toString()) + 1)
      {
        // We haven't, so cooperate
        me.data.put("current punish count", int(me.data.get("current punish count").toString()) + 1);
        //print("cooperate now that I'm done punishing");
        return true;
      }
      else
      {
        // We have, so stop punishing mode and give one last cooperate (2 total)
        me.data.put("punishing", "false");
        //print("cooperate one more time, then back to normal!");
        return true;
      }
    }
    // We haven't punished enough yet, so keep defecting
    else
    {
      me.data.put("current punish count", int(me.data.get("current punish count").toString()) + 1);
      //print("defect, since I've only defected "+int(me.data.get("current punish count").toString())+" times this punish session, and I'm going up to "+int(me.data.get("total punish count").toString()));
      return false;
    }
  }
  // We aren't punishing right now
  else
  {
    // Check his last move - if he defects, start punishing
    if (string_starts_with("defect", his_last_move))
    {
      int defect_count = 0;
      for (int i = 0; i < his_history.size() - 1; i++)
      {
        String choice = his_history.get(i).toString();
        if (string_starts_with("defect", choice))
        {
          defect_count++;
        }
      }
      me.data.put("punishing",true);
      me.data.put("total punish count",defect_count);
      me.data.put("current punish count",0);
      //print("defect because he just did. Starting punishment for "+defect_count+" round(s)");
      return true;
    }
    // He is playing nice, so will we
    else
    {
      //print("cooperate since he is playing well");
      return true;
	}
  }
}

boolean Grudger (Cell me, Cell him)
{
  // If we are punishing, defect
  if (me.data.containsKey("punishing") && boolean(me.data.get("punishing").toString()))
  {
    //print("defect, since he defected that one time");
    return false;
  }

  // Otherwise, he has played nice so far, lets check his last move
  else
  {
    ArrayList his_history = him.get_history_with(me);
    if (his_history.size() == 0) return true;
    String his_last_move = his_history.get(his_history.size() - 1).toString();

    // If his defected last move, start punishing
    if (string_starts_with("defect", his_last_move))
    {
      me.data.put("punishing", true);
      //print("start defecting, since he just defected!");
      return false;
    }
    // He has played nice, so will we
    else
    {
      //print("cooperate, since he is playing nice");
      return true;
    }
  }
}

boolean Pavlov (Cell me, Cell him)
{
  ArrayList my_history = me.get_history_with(him);
  if (my_history.size() == 0) return true;
  String my_last_move = my_history.get(my_history.size() - 1).toString();
  int my_last_payoff = int(get_string_token(" ", 2, my_last_move));

  // He plays nice, so will we
  if (my_last_payoff == int(config("both cooperate payoff")))
  {
    //print("cooperate, since he did last time, and that worked well");
    return true;
  }
  // He's a sucker - lets see how much we can get
  else if (my_last_payoff == int(config("cheaters payoff")))
  {
    //print("defect, because he was a sucker last time");
    return false;
  }
  // I was a sucker - I learned my lesson
  else if (my_last_payoff == int(config("suckers payoff")))
  {
    //print("defect, because I was a sucker last time, and won't make the mistake twice in a row");
    return false;
  }
  // We both tried to cheat, lets try to be friends
  //print("cooperate, because be both were cheating, and that didn't work out very well");
  return true;
}

boolean Punisher (Cell me, Cell him)
{
  ArrayList his_history = him.get_history_with(me);
  if (his_history.size() == 0) return true;
  String his_last_move = his_history.get(his_history.size() - 1).toString();

  // If we are in punishing mode
  if (me.data.containsKey("punishing") && boolean(me.data.get("punishing").toString()))
  {
    // Check to see if we have already punished the same number of times as he defected
    if (int(me.data.get("current punish count").toString()) >= int(me.data.get("total punish count").toString()))
    {
      // We have, so now check it we have added the extra cooperation at the end
      if (int(me.data.get("current punish count").toString()) < int(me.data.get("total punish count").toString()) + 1)
      {
        // We haven't, so cooperate
        me.data.put("current punish count", int(me.data.get("current punish count").toString()) + 1);
        //print("cooperate now that I'm done punishing");
        return true;
      }
      else
      {
        // We have, so stop punishing mode and give one last cooperate (2 total)
        me.data.put("punishing", false);
        //print("cooperate one more time, then back to normal!");
        return true;
      }
    }
    // We haven't punished enough yet, so keep defecting
    else
    {
      me.data.put("current punish count", int(me.data.get("current punish count").toString()) + 1);
      //print("defect, since I've only defected "+int(me.data.get("current punish count").toString())+" times this punish session, and I'm going up to "+int(me.data.get("total punish count").toString()));
      return false;
    }
  }
  // We aren't punishing right now
  else
  {
    // Check his last move - if he defects, start punishing
    if (string_starts_with("defect", his_last_move))
    {
      me.data.put("punishing",true);
      me.data.put("total punish count",4);
      me.data.put("current punish count",0);
      //print("defect because he just did. Starting punishment for 4 round(s)");
      return true;
    }
    // He is playing nice, so will we
    else
    {
      //print("cooperate since he is playing well");
      return true;
    }
  }
}

boolean Random (Cell me, Cell him)
{
  int r = int(random(1,100));
  if (r > 50)
  {
    //print("cooperate, with an r value of "+r);
    return true;
  }
  //print("defect, with an r value of "+r);
  return false;
}

boolean TitForTat (Cell me, Cell him)
{
  ArrayList his_history = him.get_history_with(me);
  if (his_history.size() == 0) return true;
  String his_last_move = his_history.get(his_history.size() - 1).toString();

  if (string_starts_with("defect", his_last_move))
  {
    //print("defect because he defected last move");
    return false;
  }
  //print("cooperate, because he cooperated last move");
  return true;
}

boolean TitForTatForgiving (Cell me, Cell him)
{
  ArrayList his_history = him.get_history_with(me);
  if (his_history.size() == 0) return true;
  String his_last_move = his_history.get(his_history.size() - 1).toString();

  if (string_starts_with("defect", his_last_move))
  {
    int r = int(random(1, 100));
    if (r < int(config("tftforgiving threshold")))
    {
      //print("cooperate and forgive his last move's defection");
      return true;
    }
    //print("defect because he defected last move");
    return false;
  }
  //print("cooperate because he cooperated last move");
  return true;
}

boolean TitForTatProbing (Cell me, Cell him)
{
  ArrayList his_history = him.get_history_with(me);
  if (his_history.size() == 0) return true;
  String his_last_move = his_history.get(his_history.size() - 1).toString();

  if (string_starts_with("defect", his_last_move))
  {
    //print("defect because he defected last move");
    return false;
  }
  else
  {
    int r = int(random(1, 100));
    if (r < int(config("tftprobing threshold")))
    {
      //print("defect and see if I can exploit this guy");
      return false;
    }
    //print("cooperate because he cooperated last move");
    return true;
  }
}

boolean TitForTatRandom (Cell me, Cell him)
{
  ArrayList his_history = him.get_history_with(me);
  if (his_history.size() == 0) return true;
  String his_last_move = his_history.get(his_history.size() - 1).toString();

  if (string_starts_with("defect", his_last_move))
  {
    int r = int(random(1, 100));
    if (r < int(config("tftrandom threshold")))
    {
      //print("randomly cooperate even though he defected last move");
      return true;
    }
    //print("defect because he defected last move");
    return false;
  }
  else
  {
    int r = int(random(1, 100));
    if (r < int(config("tftrandom threshold")))
    {
      //print("randomly defect even though he cooperated last move");
      return false;
    }
    //print("cooperate because he cooperated last move");
    return true;
  }
}

boolean TitForTatSuspicious (Cell me, Cell him)
{
  ArrayList his_history = him.get_history_with(me);
  if (his_history.size() == 0) return false;
  String his_last_move = his_history.get(his_history.size() - 1).toString();

  if (string_starts_with("defect", his_last_move))
  {
    //print("defect because he defected last move");
    return false;
  }
  //print("cooperate, because he cooperated last move");
  return true;
}

boolean TitForTwoTats (Cell me, Cell him)
{
  ArrayList his_history = him.get_history_with(me);
  if (his_history.size() == 0) return true;
  String his_last_move = his_history.get(his_history.size() - 1).toString();

  if (me.data.containsKey("repeat defect") && boolean(me.data.get("repeat defect").toString()))
  {
    me.data.put("repeat defect", false);
    //print("defect again because he defected two moves ago");
    return false;
  }
  if (me.data.containsKey("repeat cooperate") && boolean(me.data.get("repeat cooperate").toString()))
  {
    me.data.put("repeat cooperate", false);
    //print("cooperate again because he cooperated two moves ago");
    return false;
  }

  if (string_starts_with("defect", his_last_move))
  {
    me.data.put("repeat defect", true);
    //print("defect this move and next move because he defected");
    return false;
  }
  //print("cooperate because he cooperated");
  me.data.put("repeat cooperate", true);
  return true;
}

boolean UserControlled (Cell me, Cell him)
{
  if (me.data.containsKey("user_defects") && boolean(me.data.get("user_defects").toString()))
  {
    me.data.put("user_defects",false);
    //print("defect because you told me to");
    return false;
  }
  //print("cooperate because that is my default");
  return true;
}