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
world: there is no such thing as auto-aim in this game.

The interaction between players and the game physics allows for amazing plays:

    TODO: gif

Or absolutely terrible plays, if you're more like the average player:

    TODO: gif

Given the difficulty of the game, the built-in AI isn't very good. Most
players can surpass it within weeks of playing, and must turn to playing against
other humans online for more of a challenge. I've always wondered how one might
build a better bot for Rocket League.

So when I discovered [RLBot](https://rlbot.org/), a framework and community
dedicated to making bots for Rocket League, I was thrilled! Finally, an
interesting side project!

## The Goal

Playing Rocket League well is a high bar. It involves predicting the motion of
the ball and other players, planning your moves and executing them,
positioning, strategizing and more. Rather than attempt to meet that high bar,
for now I'll settle for a much more modest achievement: scoring a goal. More
specifically, I would like to be able to hit the ball into the goal, regardless
of the starting state of the car or ball.

Solving this for certain positions does seem quite trivial. For example, if the
car is facing the ball and the ball is between the car and the goal already,
the car may just need to make a slight turn before driving straight at the ball.

But solving this in the general case is more challenging. Consider this case,
where one is pointing away from the ball, and ball is soaring high up in the air:

    TODO: gif

Scoring in this case requires a complex string of maneuvers:

1. Left turn on the ground
2. Driving straight up the wall
3. Jumping off at the appropriate moment
4. Flipping for additional horizontal velocity in the air
5. Boosting for more height and speed, while angling the car for correct
   positioning

And there are a variety of other situations requiring their own unique set of
moves in order to efficiently hit the ball in the desired direction. But given
an arbitrary scenario, where the car and ball may be anywhere on the field and
going at any speed, how can we figure out the right set of moves that will
accomplish our goal?

## You Can Turn Anything Into A Graph

Rocket League's phsyics update at 120fps, and thus player inputs are also
sampled at 120fps. Therefore, you could imagine that players are making 120
decisions per second and providing an appropriate input at each point. The
discrete steps could be made coarser, as needed for practicality, but we still
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

