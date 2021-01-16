+++
title = "Making Rocket League Bot"
date = 2021-01-03
+++

- Introduce rocket league and RLBot
  - Physics-based, no auto-aim of any kind
  - Video/gif of good play and bad play
- Motivate the use of path planning / search
  - Describe series of moves required
- A\* Algorithm
- Hybrid A\* Algorithm
  - Grid needs to be dynamic :O
- Performance
  - Discretization
  - Heuristic choice
    - nonholonomic
    - Curves don't work as car is very dynamic, velocity curve, turning radius is
      dependent on the velocity, and velocity changes. Could not find a close form
      solution for this, we just have to simulate each step.
    - distance
    - machine learning
    - knn was better
  - Loosening the search process
- Conclusion
  - Expand to include aerials, more moves etc
  - There is a lot left out like simulating the car and ball correctly (see
    chip), handling aerials, etc
  - Link to brick

For the last few years, I've been obsessed with Rocket League, a physics-based
game where rocket-powered cars play soccer. Being physics-based means that this
game has an immensely high skill ceiling, not unlike sports in the physical
world: there is no such thing as auto-aim.

The interaction between players and the game physics allows for amazing plays:

    TODO: gif

Or positively terrible plays, if you're more like the average player:

    TODO: gif

Given the difficulty of the game, the built-in AI isn't very good. Most
players can surpass it within a few weeks of playing and must turn to online
matches against other humans for an actual challenge.

I've always wondered how one might build a better bot for Rocket League. So
when I discovered [RLBot](https://rlbot.org/), a framework and community
dedicated to making bots for Rocket League, I was thrilled. Finally, an
interesting side project!

## The Goal

Playing Rocket League well is a high bar. It involves predicting the motion of
the ball and other players, planning your moves and executing them,
positioning, strategizing, and more. Rather than attempt to meet that high bar,
for now, I'll settle for a much more modest achievement: scoring a goal. More
specifically, I would like to build a bot that can hit the ball towards the
net, regardless of the ball or car's starting state.

Solving this for certain starting states does seem relatively trivial. For
example, if the car is facing the ball and the ball is between the car and the
goal already, the car may just need to make a slight turn before driving
straight at the ball.

    TODO: gif ???

But solving this in the general case is more challenging. Consider this case,
where the ball is soaring through the air while the car is initially facing the
wrong way:

    TODO: gif

Scoring in this situation requires a complex string of maneuvers:

1. Left turn on the ground
2. Driving straight up the wall
3. Jumping off at the appropriate moment
4. Flipping for additional horizontal velocity in the air
5. Boosting for more height and speed while angling the car for correct
   positioning

Other situations require their own unique set of moves to hit the ball in the
desired direction efficiently. But given an arbitrary scenario, where the car
and ball may be anywhere on the field and going at any speed, how can we figure
out the right set of moves that will accomplish our goal?

## You Can Turn Anything Into A Graph

Rocket League's phsyics update at 120fps, and thus player inputs are also
sampled at 120fps. Therefore, you could imagine that players are making 120
decisions per second and providing an appropriate input at each point. The
discrete step. could be made coarser, as needed for practicality, but we still
end up with a long string of decisions, which result in a string of car moves,and
thus car states, that hopefully cause a goal to be scored.

This looks awfully like a tree. At each branching point, there are a set of
different inputs that could be provided to the car. These inputs result in new
car starts, and Each resulting car state is a starting point for further
branching:

    TODO car tree growing gif

This tree of inputs reaches all possible states the car can possibly reach, and
thus finding a solution can be thought of as just a tree search. Our desired
end point is a car state that collides with the ball in such a way that the
ball's post-collision velocity points at the goal. A path through the tree of
inputs that reaches that state is our solution.

Consider also that there are many solutions in this tree: there are many
different paths through it that would result in a goal. Here are two different
solutions for the same position, and there are many more:

    TODO: solution1

    TODO: solution2

What we'd like is the "optimal" solution, ie the solution which hits the ball
as early as possible. In reality, there are situations in Rocket League where
it makes more sense to slow down and get a different type of shot. But most of
the time, the player who is fastest to the ball wins it. So we'll use the time to
reach the ball as an evaluation function for optimality.

## A\*

We can use a path search algorithm, like A\*, to find an optimal path through
the input tree. A\* is an extension of Djikstra's algorithm for shortest path
search. Djikstra's algorithm relies only on the cost between nodes of the tree.
For our purposes the cost of a single edge will be the amount of time we spend
on a single inut step. The cost of the entire path will be simply the sum of
the cost along the edges, which corresponds to the total time it takes to hit
the ball.

The A\* search algorithm can achieve higher performance than Djikstra's
algorithm by making use of a heuristic to guide the search. We'll later discuss
what a good heuristic would be for Rocket League. Suffice it to say, a good
heuristic can greatly reduce the runtime of the search algorithm.

    TODO?: find A* search animation

## Hybrid A\*

But there are some challenges to applying A\* to this particular search
problem. If you consider using A\* in it's usual form, over a graph of
interconnected nodes, the states are generally very specific points. This is
helpful when there are multiple routes to the same node, as the cost for the
different paths may be directly compared, and the number of calculations
required are limited. In contrast, the state of a car in Rocket League is a set
of floating point numbers, comprising its 3-dimensional position, velocity,
angular velicity and rotation.

This is an incredibly large state space. It's possible to reach
a very similar car states via different paths. But the states will still be
slightly different, which means that the cost of each new state will be
unknown and treated as if it has never been seen before. Introducing some type
of rounding or discretization to the values when simulating car state could
solve this, but at the expense of unacceptable simulation errors. Thus it is
essential to maintain the full car state at each point in the tree.

This is where the "Hybrid" A\* algorithm comes in. This algorithm was
introduced in the
(paper)[https://ai.stanford.edu/~ddolgov/papers/dolgov_gpp_stair08.pdf]
entitled "Practical Search Techniques in Path Planning for Autonomous Driving"
by Sebastrian Thrun et al, and was used to achieve a 2nd place ranking in the
2007 DARPA Urban Challenge for self-driving cars.

The core idea behind the algorithm is to discretize the nodes of the tree, but
also maintain the full kinematic state of the car at each node. Thus the state
space being searched in the tree is greatly reduced: when other paths are found
to a state very similar to a state found before, we compare those paths
directly and only keep the one with the lowest estimated total cost. Yet we
maintain the full car state at the node for the winning path, and can thus
maintain an accurate simulation.

## Discretization / State space

The discretization applied at each node in the Hybrid A\* algorithm makes path
search more feasible in this case, but it does come at a cost: optimality. It
is possible that a node discarded as a duplicate leads to the most optimal
path.  However, it is likely that the path will still be near the globally
optimal path, as each discarded node is very close to nodes we do keep in the
path. We can tune this discretization according to the bot's performance needs,
by tweaking the bucket sizes to be as small as possible while still meeting the
performance goal.

Despite the reduction in explored state space, There are further points of
discretization required to make path search feasible, since the state space is
still very large. Most paths take a few seconds, and with inputs at 120fps, that leads to
several hundred levels in the tree. If we simply use larger simulation steps in
between nodes of our tree, that will greately reduce the state space and number
of car states that must be calculated. This is yet nother tweakable trade-off
between performance and optimality.

    TODO: gif of search space using different time discretization

Even more important than the number of levels in the tree is the branching
factor. Rocket League uses floats for the throttle, steering, roll, pitch and
yaw inputs in for example, and some sort of discretization must be applied to
that space of allowed inputs. Simplying this to driving on the ground, the car
could still boost, reverse or idle. If we omit all those possibilities and only
consider cars throttling at 100%, and going fully straight, fully left or fully
right, we finally reach a branching factor of 3. Adding boosting, a boolean
input allowing higher acceration, results in a branching factor of 6, and
drifiting brings it to a branching factor of 12.

Those 12 different inputs for ground driving are sufficient for most situations
in Rocket League where we are trying to hit the ball. It's still quite a high
branching factor, and we can't really reduce it further without giving up far
too much in optimality: drifting and boosting are absolutely essential to
efficiently moving in Rocket Leauge. So. we'll be forced to reduce the number
of levels instead to accommodate this. A very good heuristic function can also
greatly help here!

## Heuristic function

The heuristic function can be make or break for the A\* algorithm, hybrid or
otherwise. While it's always possible to find examples of graphs where even
a perfect heuristic gets the same performance as with Djikstra's algorithm, for
typical graphs a good heuristic can improve performance by multiple orders of
magnitude, by expanding far fewer nodes of the tree.

The only requirement for a heuristic for A\* search is that the it be
(admissibl)[https://en.wikipedia.org/wiki/Admissible_heuristic]. That means
it can undestimate the cost, but should never overetimate it. However, the
closer we can get to the actual cost, the better the heuristic is at
eliminating tree expansions. So our target heuristic is one which gives an
answer that is as close to the actual cost as possible, but not over.

Designing a good heuristic function for Rocket League is actually quite
challenging. One reason for this is that cars, in Rocket League and in general,
have (nonholonomic)[https://en.wikipedia.org/wiki/Nonholonomic_system]
constraints on their movement. This is just a fancy way of
saying that steering a car to make it move left or right is not independent of
its forwards or backwards movement. A car with omnidirectional wheels (ie
wheels that can go directly sideways, like the (Mecanum
wheel)[https://en.wikipedia.org/wiki/Mecanum_wheel]) would be holonomic in
constrast.

Holonomic constraints are much more commonly used for path search, and thus
often a simple distance metric can be used with some success. That is not the
case with nonholonomic systems, but let's go ahead and use euclidean distance
as a heuristic and see how it does.

Here is a visualization of all node expansions for a few different cases which
we will use as benchmark cases. The blue cuboid is a the car, and the sphere is
the ball. Each short while line is a state that was simulated while conducting
the hybrid A\* path search, and the blue line is the final solution. Note that
these tests have been done with a branching factor of six, which allows for basic
ground driving (left, right, forward) with optional boost.

With case 1, the car is facing forwards towards ball and goal, but offset in the x-axis.
We find (TODO) states have been simulated in TODO seconds.

    TODO: distance1 - forward offset

Case 2 has the car facing away from the goal, and in between the ball and goal.
It has to go the long way around, but our distance-based heuristic is not smart
enough to understand this and wastes a lot of time exploring the wrong side of
the ball. This results in (TODO) states simulated in TODO seconds.

    TODO: distance2 - backwards offset

Case 3 is another challenging one, requiring a long roundabout turn to shoot
the ball into the goal, and ends up simulating TODO states, taking TODO
seconds.

    TODO: distance3 - beside ball, turn requires large circle turn

This abysmal performance show clearly that a simple distance-based heuristic is
not sufficient, especially in more challenging cases. One reason for that is
that a car cannot go directly sideways. This results in the heuristic thinking
we are very close to reaching our  goal, when in fact the car cannot turn so
tightly.

Some have used (Reeds-Shepp
curves)[https://gieseanw.wordpress.com/2012/11/15/reeds-shepp-cars/] in order
to get a better heuristic. This is a fast way to find a lower bound for
distance.

While this is likely to work better than distance for ground driving, Rocket
League's car driving physics are more complicated than the simple models used
for Reeds-Shepp curves. For example, it is possible to drift, at the expense of
velocity, and the car's turning radius in Rocket League is dependent on its
velocity. Furthermore, turning reduces a cars velocity.

More importantly, these curves only cover basic ground driving. It will not
handle jumping, aerials (flying through the air with boost), transitioning from
the ground to the wall, and various other moves we may want to accomodate in
the general case.

I briefly attempted using a simple 2-layer neural network as a heuristic
function. Neural networks are known as universal function simulators, so it
seemed possible to make it work. The training and test sets were generated
using optimal paths found by the algorithm with the euclidean distance
heuristic. Thus, for each found path, we know the start state of the car and
what the actual cost is.

Unfortunately, the results of this were mixed and I have lost them now. I'm
sure there is a way to make it work, eg I probably should have used polar
coordinates instead of euclidean ones as inputs to the neural network. But
I moved on: while gathering data for the neural network, I had better and much
simpler idea.

You see, I now had a generated data set with car starting states in a grid
across the entire field, and with different car orientations and velocities as
well. And actual costs for each state. It looked something like this:

    TODO: csv sample

I realized I could directly use this data instead of trying to compress it into
a network! I just had to interpolate it based on how close my actual car state
is to one of the states with a pre-computed cost.

This is a classic machine learning technique known as the [k-nearest neighbors]
algorithm. A kd-tree is used to efficiently find car states in the data set
that are similar to a given one, eg one from the game. Then an average of the
costs of nearby states, weight by how close they are to the given state, can be
used as a very accurate cost.

kNN heuristic, case 1: TODO states, TODOs runtime

    TODO case1 knn

kNN heuristic, case 2: TODO states, TODOs runtime

    TODO case2 knn

kNN heuristic, case 3: TODO states, TODOs runtime

    TODO case3 knn

That's a TODOx improvement! Note that this averaging of actual costs will not
result in an admissible heuristic. But admissibility is really only a hard
requirement for optimality, which we have already given up through all the
discretization we did earlier in the process. If we're willing to give up more
optimality for performance, we can even scale the cost from the heuristic
function, which is clearly inadmissible! With a very accurate heuristic
function such as the one we have, we still get a reasonable result.

Here's the result of a TODO scaling factor on the kNN heuristic:

Scaled kNN heuristic, case 1: TODO states, TODOs runtime

    TODO case1 knn scaling

Scaled kNN heuristic, case 2: TODO states, TODOs runtime

    TODO case2 knn scaling

Scaled kNN heuristic, case 3: TODO states, TODOs runtime

    TODO case3 knn scaling

While we find some less optimal paths this way, the runtime is much better and
may be worth it. Also note that the solutions are all very similar to the
globally optimal solution. That indicates that there should be a way to create
a set of optimization passes that starts with the crude solution from a scaled
heuristic and brings it closer to an optimal one, smoothing over some of
the discretizations made while doing so. That's a future enhancement I'm
interesting in pursuing.
