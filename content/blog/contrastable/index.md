---
title: "Contrastable"
author: "Thomas Sostarics"
date: '2022-07-13'
format: hugo
editor: source
execute:
  message: false
  echo: true
---



I've been working on a package called `contrastable` on and off for the past
year or so.
The package's goal is to provide a tidy approach to setting factor contrasts
for regression analysis.
While this can be done with repeated `contrasts<-` calls, this workflow
is tedious when working with multiple factors and especially error-prone
when manually specifying contrast matrices to use.
In this latter case, the user would need to be careful to specify the correct
fractions in the correct order with the correct signs, which can be a lot to
keep track of.
These issues quickly become apparent when the number of factor levels is
greater than 2.
In this post I will:

-   Run through an example of a typical contrast coding workflow using `contrasts<-`.
    I will give an example of an error that can arise due to a typo, and show
    how to diagnose what this error actually reflects by checking the hypothesis
    matrix.
-   Show how the `contrastable` package can be used to sidestep mistakes caused
    by error-prone and tedious calls to `contrasts<-`.

## Contrast overview

Contrast coding refers to assigning numeric values to levels of a categorical
variable for use in regression analyses.
Depending on the numbers used, different comparisons can be made between the
group means of a variable.
These comparisons can correspond to particular null hypotheses that a
researcher might have, and particular combinations of numbers can encode
high-level questions like "Are there differences between levels when compared
to a common reference level?" or "Does each level differ from the levels
that came before it?"
Critically, the contrasts used don't impact the model fit but do impact the
coefficient estimates that are used to make inferences about the data.

In most cases in Linguistics, people tend to want pairwise comparisons while
retaining main effects in their model; e.g., the main effect of speech rate
on intelligibility when L1 vs L2 speakers are considered as a categorical fixed
effect.
Many people realize (or are starting to at least) that the default
"0/1 contrasts" (aka treatment or dummy coding) will only give them the simple
effect of intelligibility; that is, the effect of intelligibility for just the
L1 group.
To rectify this, researchers will opt for "the +.5/-.5 contrasts" to obtain
main effects.

However, the name for this contrast scheme is inconsistent, especially in the
2-level case.
I've seen it called sum coding, simple coding, effects coding, scaled sum
coding, helmert coding, difference coding, contrast coding, sum-to-zero coding,
and +.5/-.5 coding.
Most implementations of these contrast schemes give the same results when 2
levels are used, but yield very different contrast matrices when the number of
levels is greater than 2, and thus address very different research questions
about the data.
Here I'll use some functions from my package that provide matrices for different
contrast schemes, but typically people set these manually.

``` r
library(contrastable)
helmert_code(2) |> MASS::fractions()
```

         [,1]
    [1,]  1/2
    [2,] -1/2

``` r
scaled_sum_code(2) |> MASS::fractions()
```

      [,1]
    1  1/2
    2 -1/2

``` r
helmert_code(3) |> MASS::fractions()
```

         [,1] [,2]
    [1,]  2/3    0
    [2,] -1/3  1/2
    [3,] -1/3 -1/2

``` r
scaled_sum_code(3) |> MASS::fractions()
```

      [,1] [,2]
    1  2/3 -1/3
    2 -1/3  2/3
    3 -1/3 -1/3

Note that I use the term *scaled sum coding* for the "pairwise comparisons with
main effects" contrast scheme.
I opt for this term for three reasons.
First, I see sum coding used more frequently in statistics and econometrics to refer
to +1/-1; this is also what `contr.sum` in R returns.
Second, the salient part of going from sum coding to scaled sum coding, especially
in the 2-level case, is that there's some kind of division or scaling operation
involved; I frequently see people use `contr.sum(2)/2`, although importantly
`contr.sum(3)/3` does not yield the expected result.
Third, "simple" coding is counterintuitive to me since we're trying to *avoid*
"simple effects;" "effects coding" and "contrast coding" are largely meaningless
as all coding schemes will encode some kind of effect, and setting *any*
contrast matrix is an instance of contrast coding.
So, for the researcher trying to remember "I need to use those contrasts
where they're divided to get the main effects", it (to me) seems easy to
reach for a tool where *scaled* is in the name and is clearly distinguished
from sum coding.
If it were really up to me, I would call it "centered pairwise coding" since
you get pairwise comparisons with the intercept centered on the grand mean,
but it doesn't quite roll off the tongue and I doubt it would catch on.

## Typical approach to contrast coding

Typically when I see people in Linguistics set contrasts, they
do something like the following, using the `palmerpenguins` dataset as an
example.

``` r
library(tidyverse)
library(palmerpenguins)
penguins_with_contrasts <- penguins

# Default treatment/dummy coding for a 2 and 3 level factor
contrasts(penguins_with_contrasts$sex)
```

           male
    female    0
    male      1

``` r
contrasts(penguins_with_contrasts$species)
```

              Chinstrap Gentoo
    Adelie            0      0
    Chinstrap         1      0
    Gentoo            0      1

``` r
# Easy enough for 2 levels, -contr.sum(2)/2 is also used a lot
contrasts(penguins_with_contrasts$sex) <- c(-.5, .5) 

# Not so fun for three levels!
contrasts(penguins_with_contrasts$species) <- matrix(c(-1/3, 2/3, -1/3,
                                                       -1/3, -1/3, 2/3),
                                                     nrow = 3)
```

The chance of making a mistake increases when including more and more
categorical variables.
Catching these mistakes can be very difficult, in part because this workflow
erases the labels in the regression output.
This means you have to keep track of what `1` and `2` in the regression
coefficients correspond to.
While the `dimnames` argument can be used to set the labels, anecdotally
I rarely see people use this in their analyses when perusing code on the osf.
Below, the two sets of coefficients represent pairwise comparisons to
the `Adelie` baseline, but the intercepts differ due to how the contrasts
are set, with the first using treatment coding and the second using
scaled sum coding.
I'll start with a case that only considers the categorical variable,
but will include an additional continuous independent variable later on.

``` r
# Compare the default treatment coding with the penguins dataset
# with the contrasts we specified in penguins_with_contrasts
coef(lm(bill_length_mm ~ species, data = penguins))    
```

         (Intercept) speciesChinstrap    speciesGentoo 
           38.791391        10.042433         8.713487 

``` r
coef(lm(bill_length_mm ~ species, data = penguins_with_contrasts)) 
```

    (Intercept)    species1    species2 
      45.043364   10.042433    8.713487 

Had we made a mistake in the manually-set contrast matrix, we would reach
an incorrect conclusion about the difference between groups.

``` r
# What if we accidentally typed 1/3 instead of 2/3?
contrasts(penguins_with_contrasts$species) <- matrix(c(-1/3, 1/3, -1/3,
                                                       -1/3, -1/3, 2/3),
                                                     nrow = 3)
coef(lm(bill_length_mm ~ species, data = penguins_with_contrasts))
```

    (Intercept)    species1    species2 
      46.717103   15.063649    8.713487 

Here we can see that the intercept and the value for `species1` has changed.
To what though??
What does the new coefficient estimate represent?

### Diagnosing our mistake

To check what these numbers correspond to, we have to check the
*hypothesis matrix* that corresponds to our *contrast matrix*.
The process of obtaining the hypothesis matrix has been referred to as finding
the generalized inverse of the contrast matrix, see
[https://www.sciencedirect.com/science/article/pii/S0749596X19300695](Schad%20et%20al.%202020)
for more details.

``` r
matrix(c(1, 1, 1,         # Add a column of 1s for the intercept
         -1/3, 1/3, -1/3,
         -1/3, -1/3, 2/3),
       nrow = 3,
       dimnames = list(NULL, c('Intercept', 'species1', 'species2'))) |> 
  t() |> 
  solve() |> 
  MASS::fractions() # This function just shows numbers as fractions
```

         Intercept species1 species2
    [1,]  1/6      -3/2       -1    
    [2,]  1/2       3/2        0    
    [3,]  1/3         0        1    

Here the intercept is represented by the weighted sum of each group mean,
where the weights are shown in the intercept column.
In most cases, the intercept should reflect the grand mean, or the mean of the
group means, and so would usually have equal weights (i.e., `1/3` here) for the
levels.
In this case, we see the fractional weights are not the same.
We can verify this by calculating the weighted mean ourselves:

``` r
group_means <- 
  penguins |>
  dplyr::group_by(species) |> 
  dplyr::summarize(mean_length = mean(bill_length_mm, na.rm = TRUE)) |> 
  purrr::pluck('mean_length') |> 
  `names<-`(c('Adelie', 'Chinstrap', 'Gentoo'))

group_means
```

       Adelie Chinstrap    Gentoo 
     38.79139  48.83382  47.50488 

``` r
weighted.mean(group_means, c(1/6, 1/2, 1/3))
```

    [1] 46.7171

Similarly, the coefficient for `species1` shows the difference between the
group means of levels 1 and 2 (i.e., mean of Chinstrap - mean of Adelie) but
times a factor of `3/2`.
Crucially, if our goal is to evaluate the difference between the means of
these two levels, then our mistake in coding the hypothesis matrix will give
us a larger estimate (\~15 vs 10).
Consider a similar setup where the larger estimate was 5 instead of 0; if
we were relying on null hypothesis testing it's possible we'd get a significant
effect when really we shouldn't have.

``` r
(3/2 * group_means[['Chinstrap']]) - (3/2 * group_means[['Adelie']])
```

    [1] 15.06365

``` r
group_means[['Chinstrap']] - group_means[['Adelie']]
```

    [1] 10.04243

Point being: we made an honest mistake of typing `1/3` instead of `2/3` but
this had ramifications for the coefficients in our model output that we use
to make inferences.
In practice, because we did the multiple `contrasts<-` calls, we would likely
assume that what we did was correct in the absence of any errors.

## Tidy approach to contrasts

Here I'll show a different approach using the `contrastable` package.
This package takes a tidy approach to take care of the overhead of
labels and reference levels involved when using common contrast coding schemes.
Specifically, this package provides a series of functions that use a special
formula implementation that assigns specific meanings to each operator.
The left hand side of the formula is the factor column whose contrasts
you want to change.
The right hand side consists of (at minimum) a function to generate contrast
matrices such as `contr.treatment` or `treatment_code`.
Additional operators provide extra optional functionality:

-   `+ x`: Set reference level to level `x`
-   `* x`: Set intercept to be the mean of `x`
-   `- 3:4`: For polynomial contrasts only, drop trends `3` and `4`
-   `| c("A-B", "A-C")`: Set the comparison labels to `A-B` and `A-C` (must be
    the last operator if used)

Recall that in many cases researchers want pairwise comparisons while retaining
main effects, and so the choice of reference level for the comparisons is
very important.
By default, R uses the first level alphabetically as the reference level,
but sometimes we want to change this manually ourselves.
Here's an example where we set the `sex` and `species` factors to the two
contrast schemes we manually set before.
The `set_contrasts` function will show a message if it detects additional
factor variables in the dataframe that the user did not provide contrasts for.

``` r
# library(contrastable) was loaded earlier
penguins_df <- 
  penguins |> 
  set_contrasts(sex ~ scaled_sum_code + "male", # Set reference level with +
                species ~ scaled_sum_code + 'Adelie') 
```

    Expect contr.treatment or contr.poly for unset factors: island

``` r
contrasts(penguins_df$species) |> MASS::fractions()
```

              Chinstrap Gentoo
    Adelie    -1/3      -1/3  
    Chinstrap  2/3      -1/3  
    Gentoo    -1/3       2/3  

``` r
contrasts(penguins_df$sex) |> MASS::fractions()
```

           female
    female  1/2  
    male   -1/2  

`penguins_df` now has its contrasts set, and we can run our model as usual.
Note that we didn't have to type out any matrices ourselves, but we got the
correct contrasts that we needed.

``` r
coef(lm(bill_length_mm ~ species + bill_depth_mm, data = penguins_df))
```

         (Intercept) speciesChinstrap    speciesGentoo    bill_depth_mm 
           20.997115         9.938955        13.403279         1.394011 

If we wanted to change the labels to better reflect the comparisons being
made, we could do that in the formula too.

``` r
penguins_df <- 
  penguins_df |> 
  set_contrasts(species ~ scaled_sum_code + 'Adelie' | c('Chin-Ad', 'Gen-Ad'))

coef(lm(bill_length_mm ~ species, data = penguins_df))
```

       (Intercept) speciesChin-Ad  speciesGen-Ad 
         45.043364      10.042433       8.713487 

### Additional functions

Typically when I use this package in my analyses the `set_contrasts` function
is all I really need, but there are other functions that follow
the same syntax that provide other information.
To avoid retyping things, I'll usually keep the contrasts in a list assigned
to a separate variable and pass that to functions.

The `glimpse_contrasts` function can show information about the factors
in a dataset along with the contrast schemes that have been assigned to each
factor.

``` r
my_contrasts <- 
  list(
    sex ~ scaled_sum_code + 'female',
    species ~ helmert_code
  )

glimpse_contrasts(penguins_df, my_contrasts) |> gt::gt()
```

<div id="jyhtxllnpf" style="overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
<style>html {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Helvetica Neue', 'Fira Sans', 'Droid Sans', Arial, sans-serif;
}

#jyhtxllnpf .gt_table {
  display: table;
  border-collapse: collapse;
  margin-left: auto;
  margin-right: auto;
  color: #333333;
  font-size: 16px;
  font-weight: normal;
  font-style: normal;
  background-color: #FFFFFF;
  width: auto;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #A8A8A8;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #A8A8A8;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
}

#jyhtxllnpf .gt_heading {
  background-color: #FFFFFF;
  text-align: center;
  border-bottom-color: #FFFFFF;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#jyhtxllnpf .gt_title {
  color: #333333;
  font-size: 125%;
  font-weight: initial;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-color: #FFFFFF;
  border-bottom-width: 0;
}

#jyhtxllnpf .gt_subtitle {
  color: #333333;
  font-size: 85%;
  font-weight: initial;
  padding-top: 0;
  padding-bottom: 6px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-color: #FFFFFF;
  border-top-width: 0;
}

#jyhtxllnpf .gt_bottom_border {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#jyhtxllnpf .gt_col_headings {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
}

#jyhtxllnpf .gt_col_heading {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 6px;
  padding-left: 5px;
  padding-right: 5px;
  overflow-x: hidden;
}

#jyhtxllnpf .gt_column_spanner_outer {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: normal;
  text-transform: inherit;
  padding-top: 0;
  padding-bottom: 0;
  padding-left: 4px;
  padding-right: 4px;
}

#jyhtxllnpf .gt_column_spanner_outer:first-child {
  padding-left: 0;
}

#jyhtxllnpf .gt_column_spanner_outer:last-child {
  padding-right: 0;
}

#jyhtxllnpf .gt_column_spanner {
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: bottom;
  padding-top: 5px;
  padding-bottom: 5px;
  overflow-x: hidden;
  display: inline-block;
  width: 100%;
}

#jyhtxllnpf .gt_group_heading {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
}

#jyhtxllnpf .gt_empty_group_heading {
  padding: 0.5px;
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  vertical-align: middle;
}

#jyhtxllnpf .gt_from_md > :first-child {
  margin-top: 0;
}

#jyhtxllnpf .gt_from_md > :last-child {
  margin-bottom: 0;
}

#jyhtxllnpf .gt_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  margin: 10px;
  border-top-style: solid;
  border-top-width: 1px;
  border-top-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 1px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 1px;
  border-right-color: #D3D3D3;
  vertical-align: middle;
  overflow-x: hidden;
}

#jyhtxllnpf .gt_stub {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
}

#jyhtxllnpf .gt_stub_row_group {
  color: #333333;
  background-color: #FFFFFF;
  font-size: 100%;
  font-weight: initial;
  text-transform: inherit;
  border-right-style: solid;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
  padding-left: 5px;
  padding-right: 5px;
  vertical-align: top;
}

#jyhtxllnpf .gt_row_group_first td {
  border-top-width: 2px;
}

#jyhtxllnpf .gt_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#jyhtxllnpf .gt_first_summary_row {
  border-top-style: solid;
  border-top-color: #D3D3D3;
}

#jyhtxllnpf .gt_first_summary_row.thick {
  border-top-width: 2px;
}

#jyhtxllnpf .gt_last_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#jyhtxllnpf .gt_grand_summary_row {
  color: #333333;
  background-color: #FFFFFF;
  text-transform: inherit;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
}

#jyhtxllnpf .gt_first_grand_summary_row {
  padding-top: 8px;
  padding-bottom: 8px;
  padding-left: 5px;
  padding-right: 5px;
  border-top-style: double;
  border-top-width: 6px;
  border-top-color: #D3D3D3;
}

#jyhtxllnpf .gt_striped {
  background-color: rgba(128, 128, 128, 0.05);
}

#jyhtxllnpf .gt_table_body {
  border-top-style: solid;
  border-top-width: 2px;
  border-top-color: #D3D3D3;
  border-bottom-style: solid;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
}

#jyhtxllnpf .gt_footnotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#jyhtxllnpf .gt_footnote {
  margin: 0px;
  font-size: 90%;
  padding-left: 4px;
  padding-right: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#jyhtxllnpf .gt_sourcenotes {
  color: #333333;
  background-color: #FFFFFF;
  border-bottom-style: none;
  border-bottom-width: 2px;
  border-bottom-color: #D3D3D3;
  border-left-style: none;
  border-left-width: 2px;
  border-left-color: #D3D3D3;
  border-right-style: none;
  border-right-width: 2px;
  border-right-color: #D3D3D3;
}

#jyhtxllnpf .gt_sourcenote {
  font-size: 90%;
  padding-top: 4px;
  padding-bottom: 4px;
  padding-left: 5px;
  padding-right: 5px;
}

#jyhtxllnpf .gt_left {
  text-align: left;
}

#jyhtxllnpf .gt_center {
  text-align: center;
}

#jyhtxllnpf .gt_right {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

#jyhtxllnpf .gt_font_normal {
  font-weight: normal;
}

#jyhtxllnpf .gt_font_bold {
  font-weight: bold;
}

#jyhtxllnpf .gt_font_italic {
  font-style: italic;
}

#jyhtxllnpf .gt_super {
  font-size: 65%;
}

#jyhtxllnpf .gt_two_val_uncert {
  display: inline-block;
  line-height: 1em;
  text-align: right;
  font-size: 60%;
  vertical-align: -0.25em;
  margin-left: 0.1em;
}

#jyhtxllnpf .gt_footnote_marks {
  font-style: italic;
  font-weight: normal;
  font-size: 75%;
  vertical-align: 0.4em;
}

#jyhtxllnpf .gt_asterisk {
  font-size: 100%;
  vertical-align: 0;
}

#jyhtxllnpf .gt_slash_mark {
  font-size: 0.7em;
  line-height: 0.7em;
  vertical-align: 0.15em;
}

#jyhtxllnpf .gt_fraction_numerator {
  font-size: 0.6em;
  line-height: 0.6em;
  vertical-align: 0.45em;
}

#jyhtxllnpf .gt_fraction_denominator {
  font-size: 0.6em;
  line-height: 0.6em;
  vertical-align: -0.05em;
}
</style>
<table class="gt_table">
  
  <thead class="gt_col_headings">
    <tr>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1">factor</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_right" rowspan="1" colspan="1">n_levels</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_center" rowspan="1" colspan="1">level_names</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1">scheme</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1">reference</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1">intercept</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_center" rowspan="1" colspan="1">orthogonal</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_center" rowspan="1" colspan="1">centered</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_left" rowspan="1" colspan="1">dropped_trends</th>
      <th class="gt_col_heading gt_columns_bottom_border gt_center" rowspan="1" colspan="1">explicitly_set</th>
    </tr>
  </thead>
  <tbody class="gt_table_body">
    <tr><td class="gt_row gt_left">sex</td>
<td class="gt_row gt_right">2</td>
<td class="gt_row gt_center">female, male</td>
<td class="gt_row gt_left">scaled_sum_code</td>
<td class="gt_row gt_left">female</td>
<td class="gt_row gt_left">grand mean</td>
<td class="gt_row gt_center">NA</td>
<td class="gt_row gt_center">TRUE</td>
<td class="gt_row gt_left">NA</td>
<td class="gt_row gt_center">TRUE</td></tr>
    <tr><td class="gt_row gt_left">species</td>
<td class="gt_row gt_right">3</td>
<td class="gt_row gt_center">Adelie, Chinstrap, Gentoo</td>
<td class="gt_row gt_left">helmert_code</td>
<td class="gt_row gt_left">Gentoo</td>
<td class="gt_row gt_left">grand mean</td>
<td class="gt_row gt_center">TRUE</td>
<td class="gt_row gt_center">TRUE</td>
<td class="gt_row gt_left">NA</td>
<td class="gt_row gt_center">TRUE</td></tr>
    <tr><td class="gt_row gt_left">island</td>
<td class="gt_row gt_right">3</td>
<td class="gt_row gt_center">Biscoe, Dream, Torgersen</td>
<td class="gt_row gt_left">contr.treatment</td>
<td class="gt_row gt_left">Biscoe</td>
<td class="gt_row gt_left">mean(Biscoe)</td>
<td class="gt_row gt_center">FALSE</td>
<td class="gt_row gt_center">FALSE</td>
<td class="gt_row gt_left">NA</td>
<td class="gt_row gt_center">FALSE</td></tr>
  </tbody>
  
  
</table>
</div>

The `enlist_contrasts` function does the same thing as `set_contrasts`, but
returns a list of contrast matrices that can be used in the `contrasts`
argument of some model-fitting functions.
It also provides an easy way to show the contrast matrices in an appendix
or supplementary material.

``` r
enlist_contrasts(penguins_df, my_contrasts) |> purrr::map(MASS::fractions)
```

    Expect contr.treatment or contr.poly for unset factors: island

    $sex
           male
    female -1/2
    male    1/2

    $species
              >Adelie >Chinstrap
    Adelie     2/3       0      
    Chinstrap -1/3     1/2      
    Gentoo    -1/3    -1/2      
