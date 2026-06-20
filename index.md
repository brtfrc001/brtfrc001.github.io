---
layout: default
---

# Welcome! 

This blog is for my technical labs and write-ups.

## Recent Posts

{% for post in site.posts limit:5 %}
  <h3><a href="{{ post.url }}">{{ post.title }}</a></h3>
  <p><small>{{ post.date | date: "%B %d, %Y" }}</small></p>
  <p>{{ post.excerpt }}</p>
{% endfor %}

[View all posts]({{ "/posts/" | relative_url }})
