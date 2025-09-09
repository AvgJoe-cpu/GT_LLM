from poml import poml
from pprint import pprint

res = poml("/Users/jona/PycharmProjects/GT_LLM/src/prompts/pd_table.poml", format="openai_chat")
pprint(res)
