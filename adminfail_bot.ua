from aiogram import Bot, Dispatcher, types
from aiogram.types import ReplyKeyboardMarkup, InlineKeyboardMarkup, InlineKeyboardButton
from aiogram.utils import executor
from aiogram.contrib.fsm_storage.memory import MemoryStorage

ADMIN_BOT_TOKEN = '8025761375:AAFy7cXEiTrQUhF7_x3ks6qB6veQAJn_0yc'

bot = Bot(token=ADMIN_BOT_TOKEN)
dp = Dispatcher(bot, storage=MemoryStorage())

orders = []

main_kb = ReplyKeyboardMarkup(resize_keyboard=True)
main_kb.add("📦 Замовлення")

def build_admin_kb(index):
    return InlineKeyboardMarkup(row_width=2).add(
        InlineKeyboardButton("✅ Прийняти", callback_data=f"approve_{index}"),
        InlineKeyboardButton("❌ Відхилити", callback_data=f"reject_{index}")
    )

@dp.message_handler(commands=['start'])
async def start(msg: types.Message):
    await msg.answer("Привіт, админе!", reply_markup=main_kb)

@dp.message_handler(lambda m: m.text == "📦 Замовлення")
async def show_orders(msg: types.Message):
    if not orders:
        await msg.answer("Немає нових замовлень.")
        return
    for i, order in enumerate(orders):
        await msg.answer(order["text"], reply_markup=build_admin_kb(i))

@dp.message_handler(content_types=types.ContentType.TEXT)
async def save_order_from_client_bot(msg: types.Message):
    orders.append({
        "text": msg.text,
        "status": "очікує",
        "user_msg_id": msg.message_id
    })

@dp.callback_query_handler(lambda c: c.data.startswith("approve_") or c.data.startswith("reject_"))
async def handle_action(callback: types.CallbackQuery):
    action, idx = callback.data.split("_")
    idx = int(idx)
    if idx >= len(orders):
        await callback.answer("❌ Немає такого замовлення.")
        return

    order = orders[idx]
    status = "✅ Підтверджено" if action == "approve" else "❌ Відхилено"
    orders[idx]["status"] = status

    await callback.message.edit_text(order["text"] + f"\n\n📦 Статус: {status}")
    await callback.answer("Оновлено")

if __name__ == '__main__':
    executor.start_polling(dp, skip_updates=True)
