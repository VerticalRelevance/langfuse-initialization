import os
from langchain.llms import OpenAI
from langchain.chains import LLMChain
from langchain.chat_models import ChatAnthropic, ChatOpenAI
from langchain.prompts import ChatPromptTemplate
from langchain.schema.output_parser import StrOutputParser
from langfuse.callback import CallbackHandler

# Load API keys from environment variables
PUBLIC_KEY = "pk-lf-41e00a5f-e082-4077-bfa4-bd7e0e994b95" # these are not sensative keys
SECRET_KEY = "sk-lf-6dbc5066-324f-4622-9623-8030d2434802" # these are not sensative keys
LANGFUSE_HOST = "http://192.168.1.134:3000/" # these are not sensative keys
OPENAI_API_KEY = os.getenv('WORDPRESS_PERSONAL_OPENAI_API')

# Check if keys are set
if not all([PUBLIC_KEY, SECRET_KEY, LANGFUSE_HOST, OPENAI_API_KEY]):
    raise ValueError("API keys are not set in environment variables")

handler = CallbackHandler(PUBLIC_KEY, SECRET_KEY, LANGFUSE_HOST)

prompt = ChatPromptTemplate.from_template(
    "Give me small report about {topic}"
)
model = ChatOpenAI(
    model="gpt-4",
    openai_api_key=OPENAI_API_KEY
)  # swap Anthropic for OpenAI with `ChatOpenAI` and `openai_api_key`
output_parser = StrOutputParser()

from langchain.chains import LLMChain

chain = LLMChain(
    prompt=prompt,
    llm=model,
    output_parser=output_parser
)

# and run
out = chain.invoke(input="Artificial Intelligence", config={"callbacks":[handler]})
print(out)