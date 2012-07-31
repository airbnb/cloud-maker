#Cloud Maker

##Status

In Progress: This document is a draft that is actively being worked on.

## People

Authors: Nathan Baxter, Flo Leibert
Reviewers: Tobi Knaup, Flo Leibert

## Overview

Why are you doing this, what are the goals and non-goals. What are criteria by which you will measure success? What happens if you don't do this or fail? If relevant, what new features / usage of AirBnB does this enable?

## Background

What does a reader need to know to understand this document and the motivation for this project? Do not include aspects of your design here, this is for things like "System X is falling apart b/c it's not scalable, so we need to replace it."
Requirements


What are the application requirements? Highlight product and engineering requirements separately.
What must you have?
What load is this system expected to handle (read and writes)?
How does it grow (linearly with active users, number of searches / reservations, etc). Think about data produced / consumed and the origin thereof when answering this question.

## Design Overview

One page or less containing high level overview of salient parts of design. Circle & arrow type diagram belong here. (e.g. something like this https://github.com/airbnb/backend/blob/master/services/logging/documentation/airlog_high_level.png?raw=true)


## Software Dependencies

Which external libraries are you using?  Which software stack are you using (Ruby? Scala + Ostriche? Java + Twitter Commons)? Which build system are you using (rake, sbt, maven, ant/ivy)? Are any of these libraries a legal liability (e.g. licensed under AGPL?)

## Detailed Design

In detail, what are you proposing building and how does it work? Rule of thumb: anything that would require >100 lines of code to implement is probably significant enough to address here. Pseudo-code or IDL snippets are encouraged. The meat of the document.
Integration: what other internal or external services (API) are you dependent on or a dependency of?
Caveats


What alternatives were considered and rejected, and why?
What pre-existing systems did not meet the needs of the project?

## Testability

How will you test your system? What unit & end-to-end tests will you write?
How will you load test this?
How do you test byzantine (http://en.wikipedia.org/wiki/Byzantine_fault_tolerance)  failures?
How will you be continuously ensuring the correctness of the system when in production?
Resource Requirements


What are the machine requirements? How many servers? EBS?
Are you storing data? Do you need a relational database? Will you need to run a migration? Can you use a Key/Value/Column Store i.e. Dyson instead? If not, why not?

## Monitoring Plan

How will this service be monitored, will there be an on-call rotation? What is the plan for ops and or engineering to handle that rotation?

## Security & Privacy plan

The word "security" can mean many things. All projects must document the threats and mitigations for their project. These threats may include, but are not limited to the following:
What sort of data are you going to consume and generate?
Is any of that information in any way considered "non-public consumer information" - i.e. phone numbers, email-addresses?
Are you accepting any user-generating content, such as a form? You'll need to document your plan to not have XSS-related attacks.
How will your project or service use the network? Will it be accessible from the Internet? What machines does it need to connect to?
What user id should this server run as? Which group? Does it need special privileges?
Does it have an externally facing interface or is it just for internal consumption?
What are your plans to test with SSL? We plan to offer all services over SSL, and in some cases to mandate SSL.

## Open-source / publication

Can this project be open-sourced? Should it be developed in an entirely open source setting? Should we write blog entries? Write papers?
System Logging plan

What data are you logging and where (INFO/DEBUG logs, request logs, exception logs, etc)? What is the rate of growth and retention policy? What kinds of analysis do you plan to do on those logs, is your logging sufficient?
Event Logging plan

Will you need to run queries for analytics based on this project? Do you need real-time analytics? Does batch suffice? Do you need a new logging event category?

## Launch plan

What visible changes will this cause?
What other groups within AirBnB need to co-ordinate (Design, Sales, BD, etc)?
What are the plans for the initial rollout & possible rollback (especially if replacing an existing service)
Location of Code & Documents

Pointers to other relevant files
Where will the code live, i.e. what repository and specific location?
Where do major sources of data live?
What kind of documentation does this project need (API, ops run-book, NHO, user guide), and where will it live?

## Approximate Timeline


Who is working on this, roughly how long do you think this will take?
In what rough order will things be done?
What is current state (e.g. non-sharded prototype written, etc.)
Milestone Who Date
Initial Moon Landing  3 of us 2 weeks of work
Establish Moon Colony original team + 2 more  4 weeks of work


## Major Document History (optional)

<table>
  <tr>
    <th>Date</th>
    <th>Author</th>
    <th>Description</th>
    <th>Reviewed by</th>
    <th>Signed off by</th>
  </tr>
  <tr>
    <td>July 31st, 2012</td>
    <td>Nathan Baxter</td>
    <td>Initial Design Draft</td>
    <td></td>
    <td></td>
  </tr>
</table>
