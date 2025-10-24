import logging;
import from logging { Logger }
import from typing { Optional, Dict, List }
import from jivas.agent.core.agent { Agent }
import from jivas.agent.core.agents { Agents }
import from jivas.agent.action.action { Action }
import from jivas.agent.action.actions { Actions }
import from jivas.agent.action.interact { interact }
import from jivas.agent.memory.collection { Collection }
import from jac_cloud.plugin.jaseci { JacPlugin as Jac }
import from jivas.agent.modules.data.node_pager { NodePager }
import from jac_cloud.core.archetype {BaseCollection, NodeAnchor}
import from jivas.agent.action.interact_action { InteractAction }
import from jivas.agent.action.agent_graph_walker { agent_graph_walker }
import from jivas.agent.memory.interaction_response { InteractionMessage }
import from actions.jivas.switchboard_interact_action.user_subscription { UserSubscription }


node SwitchboardInteractAction(InteractAction) {
    static has logger:Logger = logging.getLogger(__name__);
    has available_agents: list = [];


    def touch(visitor: agent_graph_walker) -> bool {
        return True;
    }

    def execute(visitor: agent_graph_walker) -> dict {
        user_session_id = visitor.frame_node.session_id;
        current_subscription = self.get_user_location_subscription(user_session_id=user_session_id);

        if (current_subscription.get("selected_agent_id")) {
            target_agent_id = current_subscription["selected_agent_id"];
            target_agent_node = &target_agent_id;

            data = visitor.data;
            data['switchboard_agent_id'] = self.get_agent().id;

            target_frame_node = target_agent_node.get_memory().get_frame(agent_id = target_agent_id, session_id = visitor.session_id, force_session=True);

            if(visitor.channel == "whatsapp") {
                target_frame_node.set_user_name(visitor.data.get("sender_name"));
            }

            message = (target_agent_node spawn interact(
                utterance = visitor.utterance,
                agent_id = target_agent_id,
                streaming = False,
                session_id = visitor.session_id,
                frame_node = target_frame_node,
                verbose = False,
                reporting = False,
                channel = visitor.channel,
                data = data
            )).message;

            if message {
                visitor.interaction_node.set_message(message);
            } else {
                visitor.interaction_node.add_directive("There was an issue connecting you to the selected service. Please try again.");
            }

        }
    }

    def update_user_location_subscription(user_session_id: str,agent_id: str,agent_name: str ) -> bool {
        collection = self.get_collection();

        existing_sub_data = collection spawn _get_user_subscription_by_session_id(session_id_to_find=user_session_id);

        subscription_node = None;
        if (existing_sub_data and existing_sub_data.subscription_node) {
            subscription_node = existing_sub_data.subscription_node;
        } else {
            subscription_node = UserSubscription(id=user_session_id, collection_id=collection.id);
            collection ++> subscription_node;
        }

        subscription_node.set_subscription(
            session_id=user_session_id,
            agent_id=agent_id,
            agent_name=agent_name
        );
        return True;
    }

    def remove_user_location_subscription(user_session_id: str) -> bool {
        collection = self.get_collection();
        existing_sub_data = collection spawn _delete_user_subscription_by_session_id(session_id_to_find=user_session_id);

        if (existing_sub_data.subscription_node) {
            return True;
        }
        return False;
    }

    def get_user_location_subscription(user_session_id: str) -> dict {
        collection = self.get_collection();
        node_data = collection spawn _get_user_subscription_by_session_id(session_id_to_find=user_session_id);
        if (node_data and node_data.subscription_node) {
            sub_node = node_data.subscription_node;
            if (sub_node.selected_agent_id) {
                return sub_node.export_data();
            }
        }
        return {};
    }

    def list_all_subscriptions(page:int, limit:int, session_ids:list=[], agent_name:list=[]) -> list[dict] {
        # Lists all document entries in the manifest with pagination.

        collection = self.get_collection();
        pager = NodePager(NodeAnchor.Collection, page_size=limit, current_page=page);

        inbox_item_filter = [{"$and": [{"name": "UserSubscription"}, {"archetype.collection_id": collection.id}]}];
        if (session_ids and agent_name) {
            inbox_item_filter = [{"name": "OutboxItem"}, {"archetype.collection_id": collection.id, "archetype.user_session_id": {"$in": session_ids}, "archetype.selected_agent_name": {"$in": agent_name}}];
        }elif(session_ids) {
            inbox_item_filter = [{"name": "OutboxItem"}, {"archetype.collection_id": collection.id, "archetype.user_session_id": {"$in": session_ids}}];
        }elif(agent_name) {
            inbox_item_filter = [{"name": "OutboxItem"}, {"archetype.collection_id": collection.id, "archetype.selected_agent_name": {"$in": agent_name}}];
        }


        items = pager.get_page({"$or": inbox_item_filter});
        user_subscription = [];
        for item in items {
            user_subscription.append(item.export());
        }

        pagination_info = pager.to_dict();

        # get all session_ids
        sessions = [];
        if(frames := self.get_agent().get_memory().get_frames() ) {
            for frame_node in frames {
                sessions.append(frame_node.session_id);
            }
        }


        return {
            "page": page,
            "limit": limit,
            "total_items": pagination_info.get("total_items", 0),
            "total_pages": pagination_info.get("total_pages", 1),
            "has_previous": pagination_info.get("has_previous", False),
            "has_next": pagination_info.get("has_next", False),
            "user_subscription": user_subscription,
            "sessions": sessions,
            "agent_name": self.available_agents
        };
    }

    def get_switchboard_agents() -> list {
        agent_node = self.get_agent();
        available_agents = (agent_node spawn _get_switchboard_agents(switchboard_agent_id=agent_node.id)).agents;
        return available_agents;
    }

    def get_available_agents() -> list {
        return self.available_agents;
    }

    def update_available_agents(available_agents:list) -> bool {
        self.available_agents = available_agents;
        return True;
    }
}


walker _get_user_subscription_by_session_id {
    obj __specs__ {
        static has private: bool = True;
    }

    has session_id_to_find: str;
    has subscription_node: UserSubscription = None;

    can on_collection with Collection entry {
        visit [-->](`?UserSubscription)(?id == self.session_id_to_find);
    }

    can on_user_subscription with UserSubscription entry {
        self.subscription_node = here;
        disengage;
    }
}

walker _delete_user_subscription_by_session_id {
    obj __specs__ {
        static has private: bool = True;
    }

    has session_id_to_find: str;
    has subscription_node: UserSubscription = None;


    can on_collection with Collection entry {
        visit [-->](`?UserSubscription)(?id == self.session_id_to_find);
    }

    can on_user_subscription with UserSubscription entry {
        self.subscription_node = here;
        Jac.destroy(here);
    }
}

walker _list_all_subscriptions_walker {
    obj __specs__ {
        static has private: bool = True;
    }

    has page: int = 1;
    has limit: int = 10;
    has subscriptions_summary: list[dict] = [];
    has total_subscription_count: int = 0;
    has current_page: int = 1;
    has page_limit: int = 10;
    has total_pages: int = 0;

    has idx_counter: int = 0;
    has offset: int = 0;

    can on_collection with Collection entry {
        all_nodes = [-->](`?UserSubscription);
        self.total_subscription_count = len(all_nodes);
        if (self.limit > 0) {
            self.offset = (self.page - 1) * self.limit;
            self.total_pages = (self.total_subscription_count // self.limit) + (1 if self.total_subscription_count % self.limit > 0 else 0);
            self.total_pages = max(1, self.total_pages);
            self.current_page = min(self.page, self.total_pages);
            self.page_limit = self.limit;
        } else {
            self.offset = 0; self.total_pages = 1; self.current_page = 1; self.page_limit = self.total_subscription_count;
        }
        self.idx_counter = 0;
        visit [-->](`?UserSubscription);
    }
    can on_user_subscription with UserSubscription entry {
        if (self.idx_counter >= self.offset and (self.limit == 0 or len(self.subscriptions_summary) < self.limit)) {
            self.subscriptions_summary.append(here.export_data());
        }
        self.idx_counter += 1;
        if (self.limit != 0 and len(self.subscriptions_summary) >= self.limit) { disengage; }
    }
}

walker _get_switchboard_agents {
    has switchboard_agent_id:str = "";
    has can_append_agents:bool = False;
    has agents:list = [];


    obj __specs__ {
        static has private: bool = True;
    }

    can on_agents with Agents entry {
        visit [-->](`?Agent);
    }

    can on_agent with Agent entry {
        if here.id == self.switchboard_agent_id {
            if not self.can_append_agents {
                self.can_append_agents = True;
                visit [<--](`?Agents);
            }
        } else {
            self.agents.append({
                "id": here.id,
                "name": here.name,
                "description": here.description
            });
        }
    }

}
