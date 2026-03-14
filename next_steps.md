## Questions
- why does create chat have a usecase and delete chat doesnt
- can we figure out a way to handle the agents so it doesn stick out like a sore thumb, maybe send message usecase triggers the agentReplyUsecase and it direction writes into the DB, chat details screen will have to put a listener onto the DB to get updates, the agent should not call updateChat from inside the chat details view model, it should be coming as a external action
- segregate agent into a separate agents folder which directly talks to the persistence layer and not with any viewmodel or usecase
- Lets make the whole app more reactive to whatever changes happen in our db, its our source of truth
- lets also move to schema based DB handling, and make persistence a proper folder
- see if we can use something better than notification center, let the chatDetailViewModel fetch the DB
and while it fetches the DB it should wait for the loader, "a UI View should just talk to view model and nothing else"
- see if we need the message domain model to be the same as today (hash override or struct, @Model), go through the code for oppurtunities of simplification
- make a separate SendAttachmentMessageUseCase to handle all image upload biz logic
- figure out a way for optimistic updates to work with DB listeners
- save draft with a debounce and not on ever keystroke, also save it explicitly when the page is popped

## minor improvements
- when the chat list hasn't loaded show a loader


## Better test coverage
- have to handle image viewer actions
- have to check image failing to load (in the seed data we can add invalid url)
- image viewer zoom, swipe down to close, tap to close
- input bar testing more throughly
- chatdetail view has untested flow related to attachment and edit title sheet
- handle new message scroll behaviour, auto scroll to bottom when close to bottom or
show toast when far up in history, clicking on toast should take user down

Lets aim for 90% coverage of our AgentChatApp, also figure out if we can remove SDwebimageswiftui from our coverage report

## Docs
while writing tests, create a testing.md file to cover what edge cases have been covered for each file
                                                                        
This should be a crisp summary for other agents to understand whats the current state of code                                                             
                                
create a /docs folder which will have all these files which can give a crisp map of code and its edge cases and design


## NFRs
- performance optimsation of db and app launch