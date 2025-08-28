# Code conventions

## Project structure

Each project should be created as a self-contain unit, i.e. a project-oriented workflow. The R project consists of data and codes with individual scripts and functions. All scripts are stored in the `R/` folder, data in `Data` etc.

A default project template can be found [here](https://github.com/OndrejMottl/Project_template).

The default folder structure:

```         
├─ Data
|   ├─ Input
|   ├─ Processed
|   └─ Temp
├─ Outputs
|   ├─ Data
|   ├─ Figures
|   └─ Tables
├─ R
|   ├─ ___Init_project___.R
|   ├─ ___setup_project___.R
|   ├─ 00_Master.R
|   ├─ 01_Data_processing
|   |   └─ Run_01.R
|   ├─ 02_Main_analyses
|   |   └─ Run_02.R
|   ├─ 03_Supplementary_analyses
|   |   └─ Run_03.R
|   ├─ Functions
|       └─ example_fc.R
├─ README.md
├─ renv
|   └─ library_list.lock
└─ [project name].Rproj
```

### Files & folders

Folders and files can have numbering to guide a user to the sequences of analyses. However, this can be added later in the project as it causes various issues with version control.

#### Folders names

- Underscore with only the first letter capitalized (Capital_snake_style)

#### File naming {#file-naming}

- Underscore with only the first letter capitalized (Capital_snake_style)
- File name should contain dates
    - dates should be in YYYY-MM-DD
    - see [{RUtilpol}](https://github.com/HOPE-UIB-BIO/R-Utilpol-package) for easy handling of "version control of files"

##### Temporary file

- temporary data files should not hold any important information
- No links between Temp files and scripts on GitHub
- `Data/Temp` should Include in `.gitignore`

#### Safe path

All paths should be using the [here](https://here.r-lib.org/) package to make sure that they work on all machines.

### Package dependencies

The [{renv} package](https://rstudio.github.io/renv/articles/renv.html), is an R-packages dependency management, which is set up for reproducibility.

The `___Init_project___.R` script is used for the preparation of all R-packages. Mainly it will install [{RUtilpol}](https://github.com/HOPE-UIB-BIO/R-Utilpol-package) and all dependencies, which is used through the project as version control of files.

### Cascade of R scripts

This project is constructed using a *script cascade*. This means that the `00_Master.R`, located within `R` folder, executes all scripts within sub-folders of the `R` folder, which in turn, executes all their sub-folders (e.g., `R/01_Data_processing/Run_01.R` executes `R/01_Data_processing/01_full_data_process.R`, `R/01_Data_processing/02_data_overview.R`, `R/01_Data_processing/03_data_ant_counts.R`, …).

### Configuration file

The configuration file (`___setup_project___`) holds the utmost importance in a project. It serves a multitude of essential purposes, such as defining global variables, loading functions, specifying file paths, and more. Every other file within a project should initiate with a reference to the configuration file (e.g., `source("___setup_project___")`), as it aims to minimize repetition and establish an abstraction layer that allows for centralized changes. By declaring paths in the configuration file that are utilized across multiple scripts, the user can simply refer to them by their variable name in the scripts. This approach enables seamless modifications, including renaming variables or transitioning from down-sampled to full data. All you need to do is update the relevant path in one place, and the change will automatically propagate throughout your project.

### One script per task

Each script should be also self-contained. It means that it should start with loading data and finish with saving results. Therefore, each script should be able to be run without having any other data in memory (except for data from `___setup_project___`).

Each script should do just one task (see also [file name](#file-naming)). If it is hard to describe one task, it is better to split the script into several.

## Code

### Coding style

My coding style is a combination of various sources ([Tidyverse](https://style.tidyverse.org/index.html), [Google](https://google.github.io/styleguide/Rguide.html), and others). I am adopting it, as I am progressing in my career. However, style should be consistent at least within a single project.

### Code (script) structure

One script should serve one purpose and that should be obvious from its name. The script is always partitioned into clearly readable chunks (see below).

#### Script annotation (comments)

##### Script header

The script header should contain the name of the project, objectives (purpose) of that script, authors, and rough date (year of the project).

Example of a header:

```{r}
#| eval: false
#----------------------------------------------------------#
#
#
#                     Project name 
#
#                      Script name
#                      - continue
#
#                       Authors 
#                        Year
#
#----------------------------------------------------------#
```

##### Section header

Each section of a script should begin with a header which consists of a name wrapped by two lines. The name of a header should start with a capital letter. Each header name should be followed by `-----` so that it is automatically picked by IDE as a section header.

Empty lines should be placed before each header to separate chunks.

Headings can have various hierarchies:

1.  `#----------------------------------------------------------#`
2.  `#--------------------------------------------------#`
3.  `#----------------------------------------#`

Example of a header:

```{r}
#| eval: false
#----------------------------------------------------------#
# Load data -----
#----------------------------------------------------------#
```

Header names can be denoted by numbers, with subsections separated by `*.*`

Example of a numbered header:

```{r}
#| eval: false
#----------------------------------------------------------#
# 1. Estimate diversity -----
#----------------------------------------------------------#


#--------------------------------------------------#
## 1.1. Fit model -----
#--------------------------------------------------#
```

##### Single-line comments

Adding comments to code plays a pivotal role in ensuring reproducibility and preserving code knowledge for future reference. When things change or break, the user will be thankful for comments. There's no need to comment excessively or unnecessarily, but a comment describing what a large or complex chunk of code does is always helpful. The first letter of a comment is capitalized and spaced away from the pound sign (`#`).

Example of a single-line comment:

```{r}
#| eval: false
# This is a comment.
```

##### Multi-line comment

Multi-line comments should start with a capital letter and the new line should start with one tab.

Example of a multi-line comment:

```{r}
#| eval: false
# This is a very long comment, where I need to describe
#    what this code is doing
```

##### Inline comment

Inline comments should always start with a space.

Example of inline comment:

```{r}
#| eval: false
function(
	agr = 1 # This is an example of an inline comment
)
```
           
##### Commenting functions

Function decoration should be placed before each function. See [functions](#functions) for details.

#### Code width

No line of code should be longer than 80 characters (including comments). Users can visualise the 80 characters line in selected IDER

### Names of objects and function
           
```{r}
#| eval: false
  "There are only two hard things in Computer Science: cache invalidation and naming things."
```

#### Object names

Object and function should be using `snake_style`. The `.` in names is somewhat popular but it causes issues with names of methods and should be therefore avoided. The names are preferred to be very descriptive, more expressive and more explicit (note that the default `linter` setting of long names can be disabled).

The names should be nouns and start with the type of object: 

- `data_*` - for data 
	- special subcategory is `table_*` for tables (mainly as an object for reference). Note that all tables can be data but now vice versa. 
- `list_` - for lists 
- `vec_` - for vectors 
- `mod_*` - for statistical model 
- `res_` - special category, which can be used within the function to name an object to be returned (`return(res_*)`).

Examples of good names:

```{r}
#| eval: false
# data
data_diversity_survey

# list
list_diversity_individual_plots

# vector
vec_region_names

# model
mod_diversity_linear

# result
res_estimated_weight
```

#### Function names {#function-names}

Names of functions should be verbs and describe the expected functionality.

Examples of good function names

```{r}
#| eval: false
estimate_alpha_diversity()

get_first_value()

tranform_into_character()
```

##### Internal function

Note that it is possible to start a function with a `"."` (e.g., `.get_reound_value()`) flag internal functions.

#### Column (variable) names in `data.frames`

`snake_style` is preferred for column names in both `data.frames` and `tibbles`. Note that the [janitor](https://sfirke.github.io/janitor/) package can be used to edit this automatically.

### Syntax

Many of the syntax issues can be checked/fixed by [lintr](https://lintr.r-lib.org/) and [styler](https://styler.r-lib.org/index.html) packages, which can be used to automate lots of the tedious aspects.

#### Spaces (empty character)

Space (`" "`) should be always placed: 

- after a comma 
- before and after infix operators (`==`, `+`, `-`, `<-`, `~`, etc.)

Exceptions: 

- No spaces inside or outside parentheses for regular function calls 
- Operators with high precedence should not be surounced by space `:`, `::`, `:::`, `$`, `@`, `[`, `[[`, `^`, unary `-`

#### New line (`↵`)

I prefer to have code more vertical than horizontal. Therefore, there are quite a lot of new lines.

Usage of a semicolon (`;`) to indicate a new line is not preferred.

A new line should be:

##### 1. After an object assignment (`<-`)

```{r}
#| eval: false
data_diversity <-
  read_data(...)
```

An exception is an assignment of function.

```{r}
#| eval: false
get_data <- function(...) {
  ...
}
```

##### 2. After a pipe operator (`%>%`)

Note that there should be a space before a pipe

```{r}
#| eval: false
data_diversity <-
  get_data() %>%
  transform_to_percentages()
```

##### 3. After a function argument

This should be true for both function declaration and usage. The exception is a single argument.

```{r}
#| eval: false
get_data <- function(arg1 = foo,
                     arg2 = here::here()) {
  ...
}

data_diversity <-
  get_data(
    arg1 = foo,
    arg2 = here::here()
  )

vec_selected_regions <-
  get_regions(arg1 = foo)

```

##### 4. Parentheses

Each type of parentheses (brackets) has its own rules:

###### round `( )`

- should not be placed on separate first and last line
- always space *before* the bracket (*unless* it's a function)
- new line after start if it is a multi-argument function

Examples:

```{r}
#| eval: false
1 + (a + b)

get_data(arg = foo)

get_data(
  agr1 = foo,
  agr2 = here::here()
)
```

###### Square `[ ]`

- Never space before the bracket
- always space instead of missing value

Examples:

```{r}
#| eval: false
list_diversity_for_each_plot[[1]]

data_cars[, 2]
```

###### Curly `{ }`

- Use only for functions and expressions
- `{` should be the last character on a line and should never be on its own
- `}` should be the first character on a line
- Always new brackets after else unless followed by if
- Not used for chunks of code

Examples:

```{r}
#| eval: false
get_data <- function(agr1) {
  ...
}

if (
  logical_test
) {
  ...
} else {
  ...
}

try(
  expr = {
    ...
  }
)
```

#### Assignment

Always use the left assignment `<-`.

Do **NOT** use: 

- right assignment (`->`) 
- equals (`=`)

There should be a new line after the assignment. Note that rarely singe-line
assignment can be used:

```{r}
#| eval: false
data_diversity <-
  get_data()

prefered_shape <- "triangle"
```

#### Logical evaluation

Always use `TRUE` and `FALSE`, instead of `T` and `F`

### Functions {#functions}

For function calls, always state the arguments even though R can have anonymous arguments. The only exception is for functions, where arguments are not known (i.e. `...` argument).

#### Tidyverse

It is preferred to use the Tidyverse version of functions over base ones:

| Base R                 | Better Style, Performance, and Utility    |
|------------------------|-------------------------------------------|
| `read.csv()`           | `readr::read_csv()`                       |
| `df$some_column`       | `df %>% dplyr::pull(some_column)`         |
| `df$some_column = ...` | `df %>% dplyr::mutate(some_column = ...)` |
| ...                    | ...                                       |

#### Namespace

Always use the full package namespace with a function call. This helps to track the source of function in a script:

```{r}
#| eval: false
data_diversity %>%
  dplyr::mutate(
    beta_diverisity = 0
  )
```

#### Creating functions

Specific rules apply for making custom functions: 

- For naming of functions see [function names](#function-names) 
- Each function (declaration) should be placed in a separate script named the function. Therefore, there should be only a single function in each function script. 
- function should always return (`return(res_value)`)

##### Anonymous functions

In various instances, it might be better to not create a new function but to use an anonymous function (e.g. inside of `purrr::map_*()`).

In that case, the user should use tidle (`~`) for change in map default values in the function:

```{r}
#| eval: false
purrr::map(
  .f = ~ {
    mean(.x)
  }
)
```

For `purrr::pmap_*()`, the user should use `..1`, `..2`, etc

```{r}
#| eval: false
purrr::pmap(
  .l = list(
    list_1,
    list_2,
    list_3,
    .f = ~ {
      ..1 + ..2 + ..3
    }
  )
)
```

##### Function documentation

Each function should have documentation at the beginning of the function using the [roxygen2](https://roxygen2.r-lib.org/) package. This can be useful also for project-specific functions (not just within the package) as it is easier to transition to a custom package.

The roxygen2 documentation should be placed before the function declaration but keep the line limit of 80 characters. The documentation should be in the following:

```R
#' @title Title of the function
#' @description Description of the function
#' @param arg1 Description of the first argument
#' @param arg2 Description of the second argument
#' @param arg3 Description of the third argument
#' @return Description of the return value
#' @details Details about the function
#' @seealso Related functions or references
#' @export
```

##### Testing Functions

All tests are done using the [testthat](https://testthat.r-lib.org/) package. Each function should have its own test file, which is named after the function (e.g., `test-<function_name>.R`). 

Generally, the function should be tested for:

- output of correct type
- output of correct data
- handling of input errors